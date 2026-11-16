import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../importing/trackhop_client.dart';

class TrackhopConnection extends ChangeNotifier {
  TrackhopConnection(this._storage, {required this.localDesktop});

  static const _key = 'dd.trackhop.connection';
  final FlutterSecureStorage _storage;
  final bool localDesktop;
  TrackhopClient? client;
  bool busy = false;
  String message = '';
  String? _address;
  String get address =>
      _address ?? (localDesktop ? TrackhopClient.desktopAddress : '');
  bool get isConnected => client != null;

  Future<void> restore() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      final saved = await _storage.read(key: _key);
      if (saved == null) return;
      final data = jsonDecode(saved) as Map;
      final address = data['address'] as String;
      final token = data['token'] as String;
      _address = address;
      client = await _verify(address, token);
    } catch (_) {
      message = 'Confira a conexão com o Trackhop.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> connect(String address, String token) async {
    if (busy) return;
    busy = true;
    message = '';
    notifyListeners();
    try {
      final verified = await _verify(address, token);
      final origin = verified.origin.toString();
      await _storage.write(
          key: _key,
          value: jsonEncode({'address': origin, 'token': token.trim()}));
      _address = origin;
      client = verified;
    } on FormatException catch (error) {
      message = error.message;
    } catch (_) {
      message = 'Não foi possível salvar a conexão com o Trackhop.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<TrackhopClient> _verify(String address, String token) async {
    final origin = TrackhopClient.validateAddress(address);
    if (!localDesktop && origin.scheme != 'https') {
      throw const FormatException(
          'No celular, use o endereço HTTPS do seu servidor Trackhop.');
    }
    final key = token.trim();
    if (!RegExp(r'^[A-Za-z0-9_.~+/=-]{12,256}$').hasMatch(key)) {
      throw const FormatException(
          'Cole o token gerado em Ferramentas → API do Trackhop.');
    }
    final next = TrackhopClient(origin, key);
    await next.check();
    return next;
  }

  Future<void> disconnect() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      await _storage.delete(key: _key);
      client = null;
      message = '';
    } catch (_) {
      message = 'Não foi possível apagar a conexão salva.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
