import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../matching/music_engine.dart';

abstract interface class DeezerSessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureDeezerSessionStore implements DeezerSessionStore {
  const SecureDeezerSessionStore(this.storage);
  final FlutterSecureStorage storage;
  static const _key = 'dd.deezer.owned-session';
  @override
  Future<String?> read() => storage.read(key: _key);
  @override
  Future<void> write(String value) => storage.write(key: _key, value: value);
  @override
  Future<void> clear() => storage.delete(key: _key);
}

class DeezerConnectionController extends ChangeNotifier {
  DeezerConnectionController(this.store, this.engine);
  final DeezerSessionStore store;
  final MusicEngine engine;
  bool connected = false;
  bool busy = false;
  String message = '';
  String? _session;

  Future<void> restore() async {
    try {
      final saved = await store.read();
      if (saved != null) await connect(saved, persist: false);
    } catch (_) {
      message = 'Não foi possível ler a sessão Deezer no cofre.';
      notifyListeners();
    }
  }

  Future<void> connect(String value, {bool persist = true}) async {
    if (busy) return;
    busy = true;
    message = 'Conferindo a sessão na Deezer…';
    notifyListeners();
    try {
      value = value.trim();
      if (!RegExp(r'^[A-Za-z0-9_-]{80,2048}$').hasMatch(value)) {
        throw const FormatException(
            'Sessão inválida. Informe o ARL somente neste campo local.');
      }
      final response =
          await engine.call({'operation': 'deezerConnect', 'arl': value});
      if (response['connected'] != true) {
        throw const FormatException('A Deezer não autorizou a sessão.');
      }
      if (persist) await store.write(value);
      _session = value;
      connected = true;
      message =
          'Deezer conectada. A disponibilidade de cada faixa será conferida no download.';
    } catch (error) {
      connected = false;
      _session = null;
      message = error is FormatException
          ? error.message.toString()
          : 'Não foi possível acessar a sessão no cofre do sistema.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String> sessionForDownload() async {
    if (!connected || _session == null) {
      throw const FormatException('Conecte sua conta Deezer em Conexões.');
    }
    return _session!;
  }

  Future<void> disconnect() async {
    if (busy) return;
    await store.clear();
    _session = null;
    connected = false;
    message = 'Sessão removida deste dispositivo.';
    notifyListeners();
  }
}
