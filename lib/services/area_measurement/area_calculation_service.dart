import '../../core/errors/app_exception.dart';
import '../../models/area_measurement.dart';

class AreaCalculationService {
  const AreaCalculationService();

  static const goodAccuracyMeters = 5.0;
  static const fairAccuracyMeters = 15.0;
  static const minimumAreaM2 = 4.0;
  static const minimumPoints = 3;

  double areaM2(List<SurveyPoint> points) {
    _validate(points);
    final originLat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final cosLat = _cos(originLat);
    final projected = points.map((point) => _project(point, originLat, cosLat)).toList();
    var sum = 0.0;
    for (var i = 0; i < projected.length; i++) {
      final current = projected[i];
      final next = projected[(i + 1) % projected.length];
      sum += current.x * next.y - next.x * current.y;
    }
    final area = sum.abs() / 2;
    if (area < minimumAreaM2) throw ValidationException('Boundary is too small to calculate reliably.');
    return area;
  }

  double perimeterM(List<SurveyPoint> points) {
    _validate(points);
    var total = 0.0;
    for (var i = 0; i < points.length; i++) {
      total += _distance(points[i], points[(i + 1) % points.length]);
    }
    return total;
  }

  double averageAccuracy(List<SurveyPoint> points) {
    if (points.isEmpty) return 0;
    return points.fold<double>(0, (sum, point) => sum + point.accuracyMeters) / points.length;
  }

  String accuracyLabel(double meters) {
    if (meters <= goodAccuracyMeters) return 'GOOD';
    if (meters <= fairAccuracyMeters) return 'FAIR';
    return 'POOR';
  }

  void _validate(List<SurveyPoint> points) {
    if (points.length < minimumPoints) {
      throw ValidationException('Please record at least three boundary points.');
    }
    if (points.any((point) => point.accuracyMeters <= 0 || point.accuracyMeters > 500)) {
      throw ValidationException('One or more GPS points has unusable accuracy.');
    }
  }

  _XY _project(SurveyPoint point, double originLat, double cosLat) => _XY(
        _earthRadius * _rad(point.longitude) * cosLat,
        _earthRadius * _rad(point.latitude - originLat),
      );

  double _distance(SurveyPoint a, SurveyPoint b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final lat = _rad((a.latitude + b.latitude) / 2);
    final x = dLon * _earthRadius * _cos(lat);
    final y = dLat * _earthRadius;
    return (x * x + y * y).sqrt();
  }

  double _rad(double degrees) => degrees * 3.141592653589793 / 180;
  double _cos(double value) => _Cos.value(value);

  static const _earthRadius = 6371008.8;
}

class _XY {
  final double x;
  final double y;
  const _XY(this.x, this.y);
}

class _Cos {
  static double value(double value) {
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
