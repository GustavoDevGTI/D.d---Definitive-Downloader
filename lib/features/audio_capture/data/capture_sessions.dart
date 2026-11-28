import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/capture_login.dart';

/// Sessions created in the app's login window. Never logged or stored in the
/// database; on desktop and Android they live in the system vault.
abstract interface class CaptureSessionStore {
  Future<List<SessionCookie>?> read(CapturePlatform platform);
  Future<void> write(CapturePlatform platform, List<SessionCookie> cookies);
  Future<void> clear(CapturePlatform platform);
}

class SecureCaptureSessionStore implements CaptureSessionStore {
  const SecureCaptureSessionStore(this.storage);
  final FlutterSecureStorage storage;
  static String _key(CapturePlatform platform) =>
      'dd.capture.${platform.name}.owned-session';

  @override
  Future<List<SessionCookie>?> read(CapturePlatform platform) async {
    final saved = await storage.read(key: _key(platform));
    if (saved == null) return null;
    try {
      final rows = jsonDecode(saved);
      if (rows is! List) return null;
      return platformSession(
          platform, rows.map(SessionCookie.fromJson).nonNulls);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(CapturePlatform platform, List<SessionCookie> cookies) =>
      storage.write(
          key: _key(platform),
          value: jsonEncode(cookies.map((cookie) => cookie.toJson()).toList()));

  @override
  Future<void> clear(CapturePlatform platform) =>
      storage.delete(key: _key(platform));
}

/// For tests and builds without a vault: the session lasts while the app runs.
class MemoryCaptureSessionStore implements CaptureSessionStore {
  final _sessions = <CapturePlatform, List<SessionCookie>>{};
  @override
  Future<List<SessionCookie>?> read(CapturePlatform platform) async =>
      _sessions[platform];
  @override
  Future<void> write(
      CapturePlatform platform, List<SessionCookie> cookies) async {
    _sessions[platform] = List.unmodifiable(cookies);
  }

  @override
  Future<void> clear(CapturePlatform platform) async =>
      _sessions.remove(platform);
}
