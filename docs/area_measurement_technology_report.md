# Area Measurement technology report

## Libraries used

- Reused: `geolocator` for fused location access, high-accuracy streaming, permissions, and service checks.
- Reused: `sensors_plus` for optional accelerometer, gyroscope, and magnetometer support without crashing when an individual sensor is unavailable.
- No additional external hardware or survey device was introduced.
- The app uses a centralized `LocationTrackingService` abstraction so the feature is not tightly coupled to any single package implementation.

## Why these were selected

- `geolocator` is already present in the project and provides the best practical smartphone GNSS stack available within the Flutter app without requiring extra hardware.
- `sensors_plus` gives a safe optional motion context layer for acceleration and heading support when the device provides the sensor.
- The design intentionally keeps GPS as the primary source of truth and treats motion sensors as supporting information, not a substitute for GNSS.

## Existing libraries reused

- `geolocator` existing dependency was kept and wrapped in `LocationTrackingService`.
- `sensors_plus` existing dependency was retained and guarded against missing sensors.
- The current measurement math and quality services were kept in place and complemented with explicit stale-sample rejection and review gating.

## Algorithms implemented

- Accuracy-weighted smoothing using inverse-accuracy weighting within the burst filter.
- Stale-sample rejection based on timestamp age.
- Maximum-speed sanity checks for area-measurement points.
- Raw-vs-filtered area comparison for quality reporting.
- Review-required classification when a measurement differs materially from the filtered result or is unstable.
- Projected local planar geometry for small-area calculations, which avoids treating latitude/longitude as direct meter distances.

## Algorithms intentionally not used

- No map-matching or road snapping was introduced, because farm and field boundaries must follow the real walk path instead of roads.
- No external IMU or RTK/total-station stack was added, because the requirement explicitly forbids external physical measurement hardware.
- No broad multi-algorithm cascade was introduced beyond the already-used high-quality local projection and robust filtering logic; the app keeps the design simple and reliable.

## Platform limitations

- GPS accuracy varies by handset, sky visibility, tree cover, and building obstruction.
- Indoor or obstructed environments can degrade position quality even with the fused provider.
- Magnetometer and gyroscope availability is device-specific; missing sensors must degrade gracefully.
- Smartphone GNSS cannot promise centimeter precision in the way survey kits can.

## Known accuracy limitations

- The resulting measurement remains smartphone-grade and should be treated as practical field measurement, not survey-grade measurement.
- Geometric precision is still bounded by real GPS accuracy, point count, closure quality, and ground conditions.
- The app distinguishes GPS reported accuracy from measurement confidence and geometric review status.

## Tests performed

- `flutter test test/area_measurement_test.dart`
- Verified a 20m x 20m polygon approximates 400 m² within tolerance.
- Verified duplicate and unrealistic GPS points are filtered.
- Verified stale location samples are identified.
- Verified the quality assessment reports closure, confidence, and stability.

## Example measurement results

- 20m x 20m test polygon result: approximately 400 m², with the area check passing within a practical tolerance for the app’s warning thresholds.
- Quality checks show `GOOD`/`FAIR` closure labels and stable geometry when the route closes within the configured threshold.
- Raw vs filtered area comparison is retained as diagnostics rather than silently claiming a single perfect value.

## Summary

The current implementation keeps the app’s existing stack, centralizes GPS acquisition behind `LocationTrackingService`, and makes measurement quality explicit rather than claiming unsupported precision. The code remains valid on ordinary smartphone hardware and does not require any external measurement device.
