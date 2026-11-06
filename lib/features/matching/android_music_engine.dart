import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../downloads/download_cancellation.dart';
import '../downloads/transfer_progress.dart';
import 'music_engine.dart';

class _AndroidOperation {
  _AndroidOperation(this.stage, this.progress);
  final void Function(String)? stage;
  final void Function(TransferProgress)? progress;
  FormatException? error;
}

/// Android ABI runtime and owned process groups behind the existing protocol.
class AndroidMusicEngine implements MusicEngine {
  AndroidMusicEngine._() {
    channel.setMethodCallHandler((call) async {
      if (call.method != 'event') return;
      if (call.arguments is! Map) return;
      final args = Map<Object?, Object?>.from(call.arguments as Map);
      final operation = _operations[args['id']];
      if (operation == null) return;
      try {
        final line = args['line'];
        if (line is! String || line.length > 32768) {
          throw const FormatException();
        }
        final event = Map<String, dynamic>.from(jsonDecode(line) as Map);
        if (event['event'] == 'stage') {
          final message = event['message'];
          if (message is String && message.length <= 200) {
            operation.stage?.call(message);
          }
        } else if (event['event'] == 'progress') {
          final measurement = TransferProgress.fromEvent(event);
          operation.progress?.call(measurement);
        }
      } catch (_) {
        operation.error =
            const FormatException('Resposta musical Android inválida.');
        unawaited(channel.invokeMethod<void>('control',
            {'id': args['id'], 'control': 'cancel'}).catchError((Object _) {}));
      }
    });
  }
  static const channel = MethodChannel('br.com.definitivedownloader/music');
  final _operations = <String, _AndroidOperation>{};
  var _serial = 0;
  bool _available = false;
  String initializationError = '';
  @override
  bool get available => _available;

  static Future<AndroidMusicEngine> installed() async {
    final engine = AndroidMusicEngine._();
    try {
      final response = await engine._call({'operation': 'health'});
      engine._available = response['ready'] == true &&
          response['protocol'] == 1 &&
          response['platform'] == 'android' &&
          response['codecValidated'] == true &&
          response['blockVectorValidated'] == true;
      if (!engine._available) {
        engine.initializationError =
            'O motor musical Android não passou na validação de capacidade.';
      }
    } catch (_) {
      engine.initializationError =
          'Não foi possível iniciar o motor musical Android.';
    }
    return engine;
  }

  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
      {DownloadCancellation? cancellation,
      void Function(String)? onStage,
      void Function(TransferProgress)? onProgress}) {
    if (!_available) {
      throw const FormatException(
          'O motor musical Android não está disponível.');
    }
    return _call(request,
        cancellation: cancellation, onStage: onStage, onProgress: onProgress);
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> request,
      {DownloadCancellation? cancellation,
      void Function(String)? onStage,
      void Function(TransferProgress)? onProgress}) async {
    final payload = jsonEncode(request);
    if (utf8.encode(payload).length > 32768) {
      throw const FormatException('Requisição musical excedeu o limite.');
    }
    cancellation?.check();
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_serial++}';
    final operation = _AndroidOperation(onStage, onProgress);
    _operations[id] = operation;
    var previousPause = false, stopping = false, timedOut = false;
    final watch = Stopwatch()..start();
    var last = Duration.zero, elapsed = Duration.zero;
    Future<void> control(String name, [bool? enabled]) async {
      try {
        await channel.invokeMethod<void>('control', {
          'id': id,
          'control': name,
          if (enabled != null) 'enabled': enabled
        });
      } on PlatformException {/* Native operation may already have exited. */}
    }

    final timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final now = watch.elapsed;
      if (cancellation?.pauseMode != true) elapsed += now - last;
      last = now;
      final limit = request['operation'] == 'download'
          ? const Duration(minutes: 6)
          : const Duration(seconds: 65);
      if (!stopping && (cancellation?.cancelled == true || elapsed > limit)) {
        stopping = true;
        timedOut = elapsed > limit;
        unawaited(control('cancel'));
      }
      final paused = cancellation?.pauseMode == true;
      if (!stopping &&
          request['operation'] == 'download' &&
          paused != previousPause) {
        previousPause = paused;
        unawaited(control('pause', paused));
      }
    });
    try {
      final raw = await channel
          .invokeMethod<String>('run', {'id': id, 'request': payload});
      cancellation?.check();
      if (operation.error != null) throw operation.error!;
      if (timedOut) {
        throw const FormatException('A fonte demorou demais. Tente novamente.');
      }
      if (raw == null || utf8.encode(raw).length > 32768) {
        throw const FormatException('Resposta musical inválida.');
      }
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on PlatformException catch (error) {
      cancellation?.check();
      if (operation.error != null) throw operation.error!;
      throw FormatException(timedOut
          ? 'A fonte demorou demais. Tente novamente.'
          : error.message?.isNotEmpty == true && error.message!.length <= 300
              ? error.message!
              : 'A fonte musical não concluiu a operação.');
    } finally {
      timer.cancel();
      _operations.remove(id);
    }
  }
}
