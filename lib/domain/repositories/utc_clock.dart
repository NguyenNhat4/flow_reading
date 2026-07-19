/// Supplies deterministic UTC timestamps to domain operations.
abstract interface class UtcClock {
  DateTime now();
}
