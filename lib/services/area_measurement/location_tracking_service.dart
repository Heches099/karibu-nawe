import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationSample {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double speedMps;
  final double headingDegrees;
  final DateTime timestamp;

  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    this.speedMps = 0,
    this.headingDegrees = 0,
    required this.timestamp,
  });

  factory LocationSample.fromPosition(Position position) {
    final heading = position.heading.isFinite ? position.heading : 0.0;
    return LocationSample(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      speedMps: position.speed,
      headingDegrees: heading,
      timestamp: position.timestamp,
    );
  }

  bool get isUsable => accuracyMeters > 0 && accuracyMeters <= 30;
  bool get hasHeading => headingDegrees >= 0 && headingDegrees <= 360;
}

class LocationTrackingService {
  const LocationTrackingService();

  static const staleSampleSeconds = 12;

  Future<bool> ensureServiceReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied || requested == LocationPermission.deniedForever) {
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Stream<LocationSample> stream({bool highAccuracy = true}) {
    final settings = LocationSettings(
      accuracy: highAccuracy ? LocationAccuracy.bestForNavigation : LocationAccuracy.high,
      distanceFilter: 1,
      timeLimit: const Duration(seconds: 30),
    );
    return Geolocator.getPositionStream(locationSettings: settings).map(LocationSample.fromPosition);
  }

  bool isStale(LocationSample sample, {DateTime? now}) {
    final current = now ?? DateTime.now();
    return current.difference(sample.timestamp).inSeconds > staleSampleSeconds;
  }

  bool isSuspicious(LocationSample sample, {double maxSpeedMps = 8.0}) {
    return sample.speedMps > maxSpeedMps && sample.speedMps > 0 && sample.accuracyMeters <= 12;
  }

  StreamSubscription<LocationSample> subscribe({
    required void Function(LocationSample) onData,
    Function? onError,
    bool highAccuracy = true,
  }) {
    return stream(highAccuracy: highAccuracy).listen(onData, onError: onError);
  }
}
