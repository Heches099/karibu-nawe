import '../../models/area_measurement.dart';

class LocationFilter {
  final double minimumPointDistanceM;
  final double maximumJumpM;
  final double maximumWalkingSpeedMps;

  const LocationFilter({
    this.minimumPointDistanceM = 2,
    this.maximumJumpM = 70,
    this.maximumWalkingSpeedMps = 8,
  });

  SurveyPoint? accept(SurveyPoint? previous, SurveyPoint candidate) {
    if (candidate.accuracyMeters <= 0 || candidate.accuracyMeters > 100) return null;
    if (previous == null) return candidate;
    final distance = _distance(previous, candidate);
    final seconds = candidate.recordedAt.difference(previous.recordedAt).inMilliseconds / 1000;
    if (distance < minimumPointDistanceM) return null;
    if (distance > maximumJumpM) return null;
    if (seconds > 0 && distance / seconds > maximumWalkingSpeedMps) return null;
    return candidate;
  }

  /// Stabilizes a burst of readings before one boundary point is accepted.
  /// Better reported accuracy contributes more weight; distant outliers are ignored.
  SurveyPoint? stabilizeBurst(List<SurveyPoint> samples) {
    if (samples.isEmpty) return null;
    final usable = samples.where((sample) => sample.accuracyMeters > 0 && sample.accuracyMeters <= 30).toList();
    if (usable.isEmpty) return null;
    final latitudes = usable.map((sample) => sample.latitude).toList()..sort();
    final longitudes = usable.map((sample) => sample.longitude).toList()..sort();
    final medianLat = latitudes[latitudes.length ~/ 2];
    final medianLon = longitudes[longitudes.length ~/ 2];
    final selected = usable.where((sample) => _distanceTo(sample, medianLat, medianLon) <= 25).toList();
    final points = selected.isEmpty ? usable : selected;
    var totalWeight = 0.0;
    var latitude = 0.0;
    var longitude = 0.0;
    for (final sample in points) {
      final weight = 1 / (sample.accuracyMeters * sample.accuracyMeters).clamp(0.25, double.infinity);
      totalWeight += weight;
      latitude += sample.latitude * weight;
      longitude += sample.longitude * weight;
    }
    return SurveyPoint(
      latitude: latitude / totalWeight,
      longitude: longitude / totalWeight,
      accuracyMeters: points.map((sample) => sample.accuracyMeters).reduce((a, b) => a < b ? a : b),
      recordedAt: points.last.recordedAt,
    );
  }

  bool isStale(SurveyPoint point, {DateTime? now}) => (now ?? DateTime.now()).difference(point.recordedAt).inSeconds > 10;

  double _distanceTo(SurveyPoint point, double latitude, double longitude) {
    final lat = (point.latitude + latitude) * 0.5 * 0.017453292519943295;
    final x = (point.longitude - longitude) * 111320 * _cos(lat);
    final y = (point.latitude - latitude) * 110540;
    return (x * x + y * y).sqrt();
  }

  double _distance(SurveyPoint a, SurveyPoint b) {
    final lat = (a.latitude + b.latitude) * 0.5 * 0.017453292519943295;
    final x = (b.longitude - a.longitude) * 111320 * _cos(lat);
    final y = (b.latitude - a.latitude) * 110540;
    return (x * x + y * y).sqrt();
  }

  double _cos(double value) {
    var term = 1.0;
    var sum = 1.0;
    final squared = value * value;
    for (var i = 1; i <= 6; i++) {
      term *= -squared / ((2 * i - 1) * (2 * i));
      sum += term;
    }
    return sum;
  }
}

extension on double {
  double sqrt() {
    if (this <= 0) return 0;
    var result = this;
    for (var i = 0; i < 12; i++) {
      result = (result + this / result) / 2;
    }
    return result;
  }
}
