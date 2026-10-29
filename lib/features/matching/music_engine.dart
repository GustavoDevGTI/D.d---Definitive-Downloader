import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../downloads/download_service.dart';

abstract interface class MusicEngine {
  bool get available;
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
      {DownloadCancellation? cancellation, void Function(String)? onStage});
}

class WindowsMusicEngine implements MusicEngine {
  WindowsMusicEngine(this.executable);
  final String executable;
  @override
  bool get available => Platform.isWindows && File(executable).existsSync();

  static WindowsMusicEngine installed() => WindowsMusicEngine(p.join(
      p.dirname(Platform.resolvedExecutable),
      'music_engine',
      'dd_music_worker.exe'));

  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
      {DownloadCancellation? cancellation,
      void Function(String)? onStage}) async {
    if (!available) {
      throw const FormatException(
          'O motor musical não está instalado nesta plataforma.');
    }
    final payload = jsonEncode(request);
    if (utf8.encode(payload).length > 32768) {
      throw const FormatException('Requisição musical excedeu o limite.');
    }
    cancellation?.check();
    final process =
        await Process.start(executable, const [], runInShell: false);
    final result = Completer<Map<String, dynamic>>();
    var bytes = 0;
    var terminating = false;
    var timedOut = false;
    var pauseSent = false;
    var controlsOpen = request['operation'] == 'download';
    var elapsed = Duration.zero;
    final clock = Stopwatch()..start();
    var lastTick = Duration.zero;
    Future<void> stop() async {
      if (terminating) return;
      terminating = true;
      // Kill only this owned worker and its FFmpeg descendants.
      await Process.run('taskkill.exe', ['/PID', '${process.pid}', '/T', '/F']);
      process.kill();
    }

    final timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final now = clock.elapsed;
      if (cancellation?.pauseMode != true) elapsed += now - lastTick;
      lastTick = now;
      final limit = request['operation'] == 'download'
          ? const Duration(minutes: 6)
          : const Duration(seconds: 65);
      if (elapsed >= limit) {
        timedOut = true;
        unawaited(stop());
      }
      if (cancellation?.cancelled == true) {
        unawaited(stop());
      } else if (controlsOpen &&
          !terminating &&
          pauseSent != (cancellation?.pauseMode == true)) {
        pauseSent = cancellation?.pauseMode == true;
        try {
          process.stdin
              .writeln(jsonEncode({'control': 'pause', 'enabled': pauseSent}));
          unawaited(process.stdin.flush().catchError((Object _) {
            controlsOpen = false;
          }));
        } catch (_) {
          controlsOpen = false;
        }
      }
    });
    final errors = process.stderr.drain<void>();
    final streamDone = Completer<void>();
    final stream = process.stdout
        .map((chunk) {
          bytes += chunk.length;
          if (bytes > 256 * 1024) {
            throw const FormatException('Resposta musical excedeu o limite.');
          }
          return chunk;
        })
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          try {
            if (line.length > 32768) {
              throw const FormatException('Resposta musical inválida.');
            }
            final event = jsonDecode(line) as Map<String, dynamic>;
            if (event['event'] == 'stage') {
              final message = event['message'];
              if (message is String && message.length <= 200) {
                onStage?.call(message);
              }
            } else if (event['event'] == 'result' && !result.isCompleted) {
              result
                  .complete(Map<String, dynamic>.from(event['result'] as Map));
            } else if (event['event'] == 'error' && !result.isCompleted) {
              final message = event['message'];
              result.completeError(FormatException(
                  message is String && message.length <= 300
                      ? message
                      : 'A fonte musical não concluiu a operação.'));
            }
          } catch (error) {
            if (!result.isCompleted) result.completeError(error);
            unawaited(stop());
          }
        }, onError: (Object error) {
          if (!result.isCompleted) result.completeError(error);
          unawaited(stop());
        }, onDone: () {
          if (!streamDone.isCompleted) streamDone.complete();
        });
    // Attach an error handler before any child response/cancellation can arrive.
    final pending = result.future;
    unawaited(pending.then<void>((_) {}, onError: (Object _) {}));
    try {
      process.stdin.writeln(payload);
      await process.stdin.flush();
      if (!controlsOpen) await process.stdin.close();
      final code = await process.exitCode;
      await streamDone.future.timeout(const Duration(seconds: 10));
      await errors.timeout(const Duration(seconds: 10));
      cancellation?.check();
      if (!result.isCompleted) {
        throw FormatException(timedOut
            ? 'A fonte demorou demais. Tente novamente.'
            : 'O motor musical não concluiu a operação '
                '(saída $code; $bytes bytes de resposta).');
      }
      final value = await pending;
      if (code != 0) {
        throw const FormatException('O motor musical encerrou com falha.');
      }
      return value;
    } finally {
      timer.cancel();
      controlsOpen = false;
      if (request['operation'] == 'download') {
        try {
          await process.stdin.close();
        } catch (_) {/* Owned worker exited. */}
      }
      await stream.cancel();
      if (!result.isCompleted) {
        result.completeError(
            const FormatException('Operação musical interrompida.'));
      }
      if (terminating) await process.exitCode;
    }
  }
}
