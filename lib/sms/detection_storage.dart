import 'sms_parser.dart';

/// Detection state as read back on startup. It stays on this phone: SMS are
/// never backed up or synced, only the expenses made from them.
class DetectionData {
  const DetectionData({
    this.enabled = false,
    this.scannedUntil,
    this.pending = const [],
    this.accountHints = const {},
  });

  final bool enabled;

  /// SMS up to this time have been looked at; the next scan starts here.
  final DateTime? scannedUntil;

  /// Detected and waiting for the user to add or ignore.
  final List<DetectedTransaction> pending;

  /// Account or card ending → the account the user chose for it, e.g.
  /// "5678" → their HDFC card's id.
  final Map<String, String> accountHints;
}

abstract interface class DetectionStorage {
  Future<DetectionData> loadDetection();
  Future<void> saveDetectionEnabled(bool enabled);
  Future<void> saveScannedUntil(DateTime time);
  Future<void> addDetected(List<DetectedTransaction> transactions);
  Future<void> removeDetected(List<String> smsIds);
  Future<void> saveAccountHint(String hint, String accountId);
}

/// Keeps nothing; for tests and the web preview.
class InMemoryDetectionStorage implements DetectionStorage {
  @override
  Future<DetectionData> loadDetection() async => const DetectionData();

  @override
  Future<void> saveDetectionEnabled(bool enabled) async {}

  @override
  Future<void> saveScannedUntil(DateTime time) async {}

  @override
  Future<void> addDetected(List<DetectedTransaction> transactions) async {}

  @override
  Future<void> removeDetected(List<String> smsIds) async {}

  @override
  Future<void> saveAccountHint(String hint, String accountId) async {}
}
