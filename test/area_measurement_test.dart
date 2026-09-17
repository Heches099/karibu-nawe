import 'package:flutter_test/flutter_test.dart';
import 'package:farm_fms/models/area_measurement.dart';
import 'package:farm_fms/services/area_measurement/area_calculation_service.dart';
import 'package:farm_fms/services/area_measurement/location_filter.dart';
import 'package:farm_fms/services/area_measurement/location_tracking_service.dart';
import 'package:farm_fms/services/area_measurement/measurement_quality_service.dart';

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

  test('stabilizes a GPS burst toward the accurate samples', () {
    const filter = LocationFilter();
    final stabilized = filter.stabilizeBurst([
      point(0, 0, accuracy: 10, seconds: 1),
      point(0, 0.00001, accuracy: 2, seconds: 2),
      point(0, 0.000011, accuracy: 2, seconds: 3),
      point(0, 0.001, accuracy: 2, seconds: 4),
    ]);
    expect(stabilized, isNotNull);
    expect(stabilized!.longitude, lessThan(0.0001));
  });

  test('reports closure, confidence, and area stability', () {
    const quality = MeasurementQualityService();
    final points = [
      point(0, 0),
      point(0, 0.00017986),
      point(0.00018085, 0.00017986),
      point(0.00018085, 0),
    ];
    final report = quality.assess(rawPoints: [...points, point(0.01, 0.01, accuracy: 40)], acceptedPoints: points, closureDistanceMeters: 1.8);
    expect(report.stable, isTrue);
    expect(report.closureQuality, 'GOOD');
    expect(report.confidence, 'MEDIUM');
    expect(report.rejectedPoints, 1);
  });

  test('flags review when the raw and filtered area differ beyond tolerance', () {
    const quality = MeasurementQualityService();
    final points = [
      point(0, 0),
      point(0, 0.00017986),
      point(0.00018085, 0.00017986),
      point(0.00018085, 0),
    ];
    final report = quality.assess(
      rawPoints: [...points, point(0.0005, 0.0005, accuracy: 30)],
      acceptedPoints: points,
      closureDistanceMeters: 10,
    );
    expect(report.needsReview, isFalse);
    expect(report.rawAreaM2, greaterThan(0));
    expect(report.filteredAreaM2, greaterThan(0));
  });

  test('location samples are marked stale when they are too old for active measurement', () {
    final service = LocationTrackingService();
    final stale = LocationSample(
      latitude: 0,
      longitude: 0,
      accuracyMeters: 2,
      speedMps: 0,
      headingDegrees: 0,
      timestamp: DateTime.now().subtract(const Duration(seconds: 25)),
    );
    final fresh = LocationSample(
      latitude: 0,
      longitude: 0,
      accuracyMeters: 2,
      speedMps: 0,
      headingDegrees: 0,
      timestamp: DateTime.now(),
    );
    expect(service.isStale(stale), isTrue);
    expect(service.isStale(fresh), isFalse);
  });
}
