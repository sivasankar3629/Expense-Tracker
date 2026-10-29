int _lastId = 0;

/// A new id, unique on this device: the current time in microseconds, bumped
/// when two ids are made within the same tick (web clocks only tick per
/// millisecond).
String newId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  _lastId = now > _lastId ? now : _lastId + 1;
  return '$_lastId';
}
