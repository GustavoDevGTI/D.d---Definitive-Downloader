import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../storage/database.dart';
import '../../features/player/data/media_kit_engine.dart';
import '../../features/player/data/player_library.dart';
import '../../features/library/domain/models.dart';

Future<int> diagnosePlayer(List<String> arguments) async {
  MediaKitEngine? engine;
  try {
    engine = MediaKitEngine();
    await engine.volume(0);
    final fileArg =
        arguments.where((v) => v.startsWith('--player-file=')).firstOrNull;
    final previewArg =
        arguments.where((v) => v.startsWith('--player-preview=')).firstOrNull;
    var uri = Uri.file(fileArg?.substring('--player-file='.length) ??
            p.join(p.dirname(Platform.resolvedExecutable), 'data',
                'flutter_assets', 'assets', 'demo', 'tone.mp3'))
        .toString();
    if (previewArg != null) {
      final id = previewArg.substring('--player-preview='.length);
      if (!RegExp(r'^\d+$').hasMatch(id)) {
        throw const FormatException('ID inválido.');
      }
      final item = await const PlayerLibrary(AppDatabase('')).online(Candidate(
          title: 'Verificação',
          artist: '',
          album: '',
          durationMs: 0,
          pageUrl: 'https://www.deezer.com/track/$id',
          previewUrl: '',
          coverUrl: '',
          kind: SourceKind.deezerFull));
      if (item == null) throw const FormatException('Sem prévia.');
      uri = item.uri;
    }
    var failed = false;
    final subscription = engine.events.listen((event) {
      if (event.failed) failed = true;
    });
    await engine.open(uri);
    Future<void> until(bool Function() condition) async {
      final clock = Stopwatch()..start();
      while (!condition() &&
          clock.elapsed < const Duration(seconds: 12) &&
          !failed) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!condition() || failed) {
        throw const FormatException('Reprodução não confirmada.');
      }
    }

    await until(() => (engine!.measurements['positionMs'] as int) > 350);
    await engine.pause();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final paused = engine.measurements['positionMs'] as int;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (((engine.measurements['positionMs'] as int) - paused).abs() > 150) {
      throw const FormatException('Pausa não confirmada.');
    }
    await engine.seek(const Duration(seconds: 2));
    await until(() => (engine!.measurements['positionMs'] as int) >= 1800);
    await engine.volume(.237);
    await until(
        () => ((engine!.measurements['volume'] as num) - 23.7).abs() < .1);
    await engine.volume(0);
    await engine.play();
    await until(() => (engine!.measurements['positionMs'] as int) > 2300);
    await engine.pause();
    stdout.writeln(jsonEncode({
      'playerReady': true,
      'mode': previewArg == null ? 'local' : 'preview',
      'durationMs': engine.measurements['durationMs'],
      'pause': true,
      'seek': true,
      'continuousVolume': true
    }));
    await subscription.cancel();
    return 0;
  } catch (_) {
    stdout.writeln(jsonEncode({
      'playerReady': false,
      'message': 'Não foi possível validar a reprodução nativa.'
    }));
    return 1;
  } finally {
    await engine?.dispose();
  }
}
