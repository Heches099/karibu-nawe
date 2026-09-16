import 'package:flutter_test/flutter_test.dart';
import 'package:farm_fms/models/area_measurement.dart';
import 'package:farm_fms/services/area_measurement/area_calculation_service.dart';
import 'package:farm_fms/services/area_measurement/location_filter.dart';

void main() {
  final calculator = const AreaCalculationService();

  SurveyPoint point(double lat, double lon, {double accuracy = 2, int seconds = 0}) => SurveyPoint(
        latitude: lat,
        longitude: lon,
        accuracyMeters: accuracy,
        recordedAt: DateTime(2026, 1, 1).add(Duration(seconds: seconds)),
      );

  test('calculates a small 20m by 20m polygon approximately', () {
    final points = [
      point(0, 0),
      point(0, 0.00017986),
      point(0.00018085, 0.00017986),
      point(0.00018085, 0),
    ];
    expect(calculator.areaM2(points), closeTo(400, 12));
    expect(calculator.accuracyLabel(calculator.averageAccuracy(points)), 'GOOD');
  });

  test('converts square metres to hectares and acres', () {
    final measurement = AreaMeasurement(
      id: 'm1',
      measuredBy: 'u1',
      startedAt: DateTime(2026),
      areaM2: 600,
      perimeterM: 100,
      averageAccuracyMeters: 3,
      sensorInfo: 'GPS',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(measurement.hectares, closeTo(0.06, 0.0001));
    expect(measurement.acres, closeTo(0.1483, 0.0002));
  });

  test('rejects too few points and zero area', () {
    expect(() => calculator.areaM2([point(0, 0), point(0, 0.0001)]), throwsA(isA<Exception>()));
    expect(() => calculator.areaM2([point(0, 0), point(0, 0), point(0, 0)]), throwsA(isA<Exception>()));
  });

  test('filters duplicate and unrealistic GPS points', () {
    const filter = LocationFilter();
    final first = point(0, 0, seconds: 1);
    expect(filter.accept(null, first), first);
    expect(filter.accept(first, point(0, 0.000001, seconds: 2)), isNull);
    expect(filter.accept(first, point(0, 0.001, seconds: 2)), isNull);
    expect(filter.accept(first, point(0, 0.00003, seconds: 3)), isNotNull);
  });
}
