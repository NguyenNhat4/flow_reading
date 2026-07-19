import 'package:flow_reading/domain/repositories/utc_clock.dart';

/// Supplies timestamps from the device system clock.
final class SystemUtcClock implements UtcClock {
  const SystemUtcClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
