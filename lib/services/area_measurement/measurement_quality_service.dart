import 'dart:math' as math;

import '../../core/errors/app_exception.dart';
import '../../models/area_measurement.dart';
import 'area_calculation_service.dart';

class MeasurementQualityReport {
  final double score;
  final String confidence;
  final double averageAccuracyMeters;
  final double closureDistanceMeters;
  final String closureQuality;
  final double rawAreaM2;
  final double filteredAreaM2;
  final bool stable;
  final int acceptedPoints;
  final int rejectedPoints;
  final double distanceTravelledM;

  const MeasurementQualityReport({
    required this.score,
    required this.confidence,
    required this.averageAccuracyMeters,
    required this.closureDistanceMeters,
    required this.closureQuality,
    required this.rawAreaM2,
    required this.filteredAreaM2,
    required this.stable,
    required this.acceptedPoints,
    required this.rejectedPoints,
    required this.distanceTravelledM,
  });

  String get scoreLabel => '${score.round()}/100';

  double get areaDifferenceRatio {
    if (rawAreaM2 <= 0) return 0;
    return (rawAreaM2 - filteredAreaM2).abs() / rawAreaM2;
  }

  bool get needsReview => areaDifferenceRatio > 0.2 || !stable;
}

class MeasurementQualityService {
  final AreaCalculationService calculator;

  const MeasurementQualityService({this.calculator = const AreaCalculationService()});

  static const targetAccuracyMeters = 5.0;
  static const staleSampleSeconds = 10;
  static const goodClosureMeters = 5.0;
  static const fairClosureMeters = 12.0;
  static const stabilityTolerance = 0.20;

  SurveyPoint stabilize(List<SurveyPoint> samples) {
    if (samples.isEmpty) throw ValidationException('No GPS samples available.');
    final usable = samples.where((sample) => sample.accuracyMeters > 0 && sample.accuracyMeters <= 30).toList();
    if (usable.isEmpty) throw ValidationException('No usable GPS samples were received.');
    final medianLat = _median(usable.map((sample) => sample.latitude).toList());
    final medianLon = _median(usable.map((sample) => sample.longitude).toList());
    final robust = usable.where((sample) => _distanceFrom(sample, medianLat, medianLon) <= 25).toList();
    final selected = robust.isEmpty ? usable : robust;
    var weightTotal = 0.0;
    var latitude = 0.0;
    var longitude = 0.0;
    for (final sample in selected) {
      final weight = 1 / math.max(sample.accuracyMeters * sample.accuracyMeters, 0.25);
      weightTotal += weight;
      latitude += sample.latitude * weight;
      longitude += sample.longitude * weight;
    }
    return SurveyPoint(
      latitude: latitude / weightTotal,
      longitude: longitude / weightTotal,
      accuracyMeters: selected.map((sample) => sample.accuracyMeters).reduce(math.min),
      recordedAt: selected.last.recordedAt,
    );
  }

  MeasurementQualityReport assess({
    required List<SurveyPoint> rawPoints,
    required List<SurveyPoint> acceptedPoints,
    required double closureDistanceMeters,
  }) {
    if (acceptedPoints.length < AreaCalculationService.minimumPoints) {
      throw ValidationException('Record more boundary points before reviewing the measurement.');
    }
    final rawArea = calculator.areaM2(acceptedPoints);
    final qualityPoints = acceptedPoints.where((point) => point.accuracyMeters <= 15).toList();
    final filteredPoints = qualityPoints.length >= AreaCalculationService.minimumPoints ? qualityPoints : acceptedPoints;
    final filteredArea = calculator.areaM2(filteredPoints);
    final averageAccuracy = calculator.averageAccuracy(acceptedPoints);
    final accuracyScore = _bounded(100 - averageAccuracy * 10);
    final closureScore = _bounded(100 - closureDistanceMeters * 5);
    final sampleScore = _bounded(acceptedPoints.length * 4);
    final stabilityRatio = rawArea == 0 ? 1 : (rawArea - filteredArea).abs() / rawArea;
    final stable = stabilityRatio <= stabilityTolerance;
    final score = _bounded(accuracyScore * 0.45 + closureScore * 0.30 + sampleScore * 0.15 + (stable ? 10 : 0));
    final report = MeasurementQualityReport(
      score: score,
      confidence: score >= 80 ? 'HIGH' : score >= 60 ? 'MEDIUM' : 'LOW',
      averageAccuracyMeters: averageAccuracy,
      closureDistanceMeters: closureDistanceMeters,
      closureQuality: closureDistanceMeters <= goodClosureMeters ? 'GOOD' : closureDistanceMeters <= fairClosureMeters ? 'FAIR' : 'POOR',
      rawAreaM2: rawArea,
      filteredAreaM2: filteredArea,
      stable: stable,
      acceptedPoints: acceptedPoints.length,
      rejectedPoints: math.max(rawPoints.length - acceptedPoints.length, 0),
      distanceTravelledM: calculator.perimeterM(acceptedPoints),
    );
    return report;
  }

  double distanceMeters(SurveyPoint a, SurveyPoint b) => _distanceFrom(a, b.latitude, b.longitude);

  double _distanceFrom(SurveyPoint point, double latitude, double longitude) {
    final latScale = 110540.0;
    final lonScale = 111320.0 * math.cos(latitude * math.pi / 180);
    final y = (point.latitude - latitude) * latScale;
    final x = (point.longitude - longitude) * lonScale;
    return math.sqrt(x * x + y * y);
  }

  double _median(List<double> values) {
    values.sort();
    final middle = values.length ~/ 2;
    return values.length.isOdd ? values[middle] : (values[middle - 1] + values[middle]) / 2;
  }

  double _bounded(double value) => value.clamp(0, 100).toDouble();
}
