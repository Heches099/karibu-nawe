import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

enum MovementState { stationary, walking, turning, unknown }

class SensorFusionService {
  SensorFusionService();

  bool hasAccelerometer = false;
  bool hasGyroscope = false;
  bool hasMagnetometer = false;

  MovementState movementState = MovementState.unknown;
  double currentHeadingDegrees = 0;
  double turnRateDegreesPerSecond = 0;
  double accelerationMagnitude = 0;
  bool get hasMotionContext => hasAccelerometer || hasGyroscope || hasMagnetometer;

  void updateAccelerometer(AccelerometerEvent event) {
    hasAccelerometer = true;
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    accelerationMagnitude = magnitude;

    if (magnitude < 0.5) {
      movementState = MovementState.stationary;
    } else if (magnitude < 2.2) {
      movementState = MovementState.walking;
    } else {
      movementState = MovementState.unknown;
    }
  }

  void updateGyroscope(GyroscopeEvent event) {
    hasGyroscope = true;
    final rate = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    turnRateDegreesPerSecond = rate * 57.2958;
    if (turnRateDegreesPerSecond > 18) {
      movementState = MovementState.turning;
    } else if (movementState == MovementState.turning && turnRateDegreesPerSecond < 8) {
      movementState = MovementState.walking;
    }
  }

  void updateMagnetometer(MagnetometerEvent event) {
    hasMagnetometer = true;
    final heading = math.atan2(event.y, event.x) * 180 / math.pi;
    currentHeadingDegrees = heading < 0 ? heading + 360 : heading;
  }

  String get summary {
    final accel = hasAccelerometer ? 'Accel ✓' : 'Accel —';
    final gyro = hasGyroscope ? 'Gyro ✓' : 'Gyro —';
    final mag = hasMagnetometer ? 'Compass ✓' : 'Compass —';
    return '$accel · $gyro · $mag';
  }

  String get movementSummary {
    switch (movementState) {
      case MovementState.stationary:
        return 'STATIONARY';
      case MovementState.walking:
        return 'WALKING';
      case MovementState.turning:
        return 'TURNING';
      case MovementState.unknown:
        return 'UNKNOWN';
    }
  }
}
