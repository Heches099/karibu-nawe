import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/utils/format.dart';
import '../../services/area_measurement/area_calculation_service.dart';
import '../../services/area_measurement/location_filter.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/forms.dart';

class AreaMeasurementScreen extends StatefulWidget {
  final Task task;

  const AreaMeasurementScreen({super.key, required this.task});

  @override
  State<AreaMeasurementScreen> createState() => _AreaMeasurementScreenState();
}

class _AreaMeasurementScreenState extends State<AreaMeasurementScreen> {
  final _length = TextEditingController();
  final _width = TextEditingController();
  final _manualArea = TextEditingController();
  final _notes = TextEditingController();
  final _calculator = const AreaCalculationService();
  final _filter = const LocationFilter();
  final _points = <SurveyPoint>[];
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  bool _measuring = false;
  bool _paused = false;
  bool _sensorAvailable = false;
  double? _accuracy;
  String? _error;
  DateTime? _startedAt;
  DateTime? _finishedAt;
  double? _calculatedArea;
  double? _calculatedPerimeter;
  String _mode = 'manual';

  @override
  void dispose() {
    _stopStreams();
    _length.dispose();
    _width.dispose();
    _manualArea.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _startGps() async {
    setState(() => _error = null);
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _error = 'Location is disabled. Enable GPS and try again.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => _error = 'Location permission is required for boundary measurement.');
      return;
    }
    final started = DateTime.now();
    setState(() {
      _mode = 'gps';
      _measuring = true;
      _paused = false;
      _startedAt = started;
      _finishedAt = null;
      _calculatedArea = null;
      _calculatedPerimeter = null;
      _points.clear();
    });
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 2),
    ).listen(_onPosition, onError: (Object error) {
      if (mounted) setState(() => _error = 'Location updates are unavailable. You can save a manual measurement instead.');
    });
    try {
      _accelerometerSubscription = accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen((_) {
        if (mounted && !_sensorAvailable) setState(() => _sensorAvailable = true);
      });
      _gyroscopeSubscription = gyroscopeEventStream(samplingPeriod: SensorInterval.normalInterval).listen((_) {
        if (mounted && !_sensorAvailable) setState(() => _sensorAvailable = true);
      });
    } catch (_) {
      _sensorAvailable = false;
    }
  }

  void _onPosition(Position position) {
    if (!_measuring || _paused) return;
    final point = SurveyPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      recordedAt: position.timestamp,
    );
    final accepted = _filter.accept(_points.isEmpty ? null : _points.last, point);
    if (accepted == null) return;
    setState(() {
      _points.add(accepted);
      _accuracy = accepted.accuracyMeters;
    });
  }

  void _togglePause() => setState(() => _paused = !_paused);

  void _finishGps() {
    if (_points.length < AreaCalculationService.minimumPoints) {
      setState(() => _error = 'Continue walking until at least three boundary points are recorded.');
      return;
    }
    try {
      final area = _calculator.areaM2(_points);
      setState(() {
        _measuring = false;
        _finishedAt = DateTime.now();
        _calculatedArea = area;
        _calculatedPerimeter = _calculator.perimeterM(_points);
        _error = null;
      });
      _stopStreams();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _calculateManual() {
    final length = double.tryParse(_length.text.trim());
    final width = double.tryParse(_width.text.trim());
    if (length == null || width == null || length <= 0 || width <= 0) {
      setState(() => _error = 'Enter positive length and width values.');
      return;
    }
    setState(() {
      _mode = 'manual';
      _calculatedArea = length * width;
      _calculatedPerimeter = 2 * (length + width);
      _startedAt = DateTime.now();
      _finishedAt = DateTime.now();
      _error = null;
    });
  }

  Future<void> _save() async {
    final area = _calculatedArea;
    if (area == null || area <= 0) {
      setState(() => _error = 'Calculate an area before saving.');
      return;
    }
    final store = context.read<AppStore>();
    final now = DateTime.now();
    final measurement = AreaMeasurement(
      id: store.genId(),
      taskId: widget.task.id,
      measuredBy: store.session?.id ?? store.actorName,
      startedAt: _startedAt ?? now,
      finishedAt: _finishedAt ?? now,
      points: List.unmodifiable(_points),
      smoothedPoints: List.unmodifiable(_points),
      areaM2: area,
      perimeterM: _calculatedPerimeter ?? 0,
      averageAccuracyMeters: _points.isEmpty ? 0 : _calculator.averageAccuracy(_points),
      sensorInfo: _mode == 'manual' ? 'Manual dimensions' : (_sensorAvailable ? 'GPS + motion sensors' : 'GPS; motion sensors unavailable'),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdAt: now,
      updatedAt: now,
    );
    try {
      await store.saveAreaMeasurement(measurement);
      if (mounted) {
        showSuccess(context, 'Area saved: ${fmtArea(area)}');
        Navigator.pop(context, measurement);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _reset() {
    _stopStreams();
    setState(() {
      _points.clear();
      _measuring = false;
      _paused = false;
      _calculatedArea = null;
      _calculatedPerimeter = null;
      _accuracy = null;
      _error = null;
    });
  }

  void _stopStreams() {
    _locationSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _locationSubscription = null;
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accuracy = _accuracy;
    final accuracyLabel = accuracy == null ? 'Waiting' : _calculator.accuracyLabel(accuracy);
    return Scaffold(
      appBar: AppBar(title: const Text('Measure Area')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.task.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(widget.task.field, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'manual', label: Text('Manual dimensions'), icon: Icon(Icons.straighten)),
              ButtonSegment(value: 'gps', label: Text('Walk boundary'), icon: Icon(Icons.gps_fixed)),
            ],
            selected: {_mode},
            onSelectionChanged: (values) {
              if (!_measuring) setState(() => _mode = values.first);
            },
          ),
          const SizedBox(height: 16),
          if (_mode == 'manual') _manualPanel() else _gpsPanel(accuracyLabel),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)', alignLabelWithHint: true)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _calculatedArea == null ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Area to Task'),
          ),
        ],
      ),
    );
  }

  Widget _manualPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Manual measurement', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _length, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Length', suffixText: 'm'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _width, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Width', suffixText: 'm'))),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _calculateManual, icon: const Icon(Icons.calculate_outlined), label: const Text('Calculate area')),
            if (_calculatedArea != null) _resultCard(),
          ],
        ),
      ),
    );
  }

  Widget _gpsPanel(String accuracyLabel) {
    final accuracy = _accuracy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [const Icon(Icons.gps_fixed), const SizedBox(width: 8), Text(_measuring ? (_paused ? 'PAUSED' : 'MEASURING') : 'MEASUREMENT READY', style: const TextStyle(fontWeight: FontWeight.w800))]),
            const SizedBox(height: 12),
            Wrap(spacing: 18, runSpacing: 8, children: [
              Text(accuracy == null ? 'GPS: —' : 'GPS: $accuracyLabel ${accuracy.toStringAsFixed(1)} m'),
              Text('Points: ${_points.length}'),
              Text('Sensors: ${_sensorAvailable ? 'Available' : 'Unavailable'}'),
              Text('Network: local save'),
            ]),
            const SizedBox(height: 12),
            Container(
              height: 220,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
              child: CustomPaint(painter: _SurveyPainter(_points, Theme.of(context).colorScheme)),
            ),
            const SizedBox(height: 12),
            if (_calculatedArea != null) _resultCard(),
            Wrap(spacing: 8, children: [
              if (!_measuring && _calculatedArea == null) FilledButton.icon(onPressed: _startGps, icon: const Icon(Icons.play_arrow), label: const Text('Start measurement')),
              if (_measuring) OutlinedButton.icon(onPressed: _togglePause, icon: Icon(_paused ? Icons.play_arrow : Icons.pause), label: Text(_paused ? 'Resume' : 'Pause')),
              if (_measuring) FilledButton.icon(onPressed: _finishGps, icon: const Icon(Icons.stop), label: const Text('Finish boundary')),
              OutlinedButton.icon(onPressed: _reset, icon: const Icon(Icons.restart_alt), label: const Text('Reset')),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _resultCard() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(children: [
          Expanded(child: Text('Area\n${fmtArea(_calculatedArea!)}', style: const TextStyle(fontWeight: FontWeight.w800))),
          Expanded(child: Text('Hectares\n${(_calculatedArea! / 10000).toStringAsFixed(3)}', style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text('Perimeter\n${(_calculatedPerimeter ?? 0).round()} m', style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}

class _SurveyPainter extends CustomPainter {
  final List<SurveyPoint> points;
  final ColorScheme scheme;
  const _SurveyPainter(this.points, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      final textPainter = TextPainter(text: const TextSpan(text: 'Waiting for GPS points…'), textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
      return;
    }
    final minLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLon = points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLon = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
    final latSpan = (maxLat - minLat).abs() + 0.00001;
    final lonSpan = (maxLon - minLon).abs() + 0.00001;
    Offset position(SurveyPoint p) => Offset((p.longitude - minLon) / lonSpan * (size.width - 24) + 12, (1 - (p.latitude - minLat) / latSpan) * (size.height - 24) + 12);
    final path = Path()..moveTo(position(points.first).dx, position(points.first).dy);
    for (final point in points.skip(1)) {
      path.lineTo(position(point).dx, position(point).dy);
    }
    if (points.length >= 3) path.close();
    canvas.drawPath(path, Paint()..color = scheme.primary.withValues(alpha: 0.16)..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = scheme.primary..style = PaintingStyle.stroke..strokeWidth = 3);
    for (final point in points) {
      canvas.drawCircle(position(point), 4, Paint()..color = scheme.secondary);
    }
  }

  @override
  bool shouldRepaint(covariant _SurveyPainter oldDelegate) => oldDelegate.points != points;
}
