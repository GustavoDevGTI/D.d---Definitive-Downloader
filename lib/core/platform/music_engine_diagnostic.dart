import 'dart:convert';
import 'dart:io';
import '../../features/matching/music_engine.dart';

/// Explicit native-process diagnostic. Never opens a saved account or vault.
Future<int> diagnoseMusicEngine(WindowsMusicEngine engine) async {
  final report = <String, Object?>{'real_account_used': false};
  var code = 1;
  try {
    report['health'] = (await engine.call({'operation': 'health'}))['ready'];
    try {
      await engine.call({'operation': 'deezerConnect', 'arl': 'a' * 192});
      report['synthetic_session_rejected'] = false;
    } on FormatException catch (error) {
      report['synthetic_session_rejected'] =
          error.message.contains('expirou ou não foi autorizada');
      report['message'] = error.message;
    }
    if (report['health'] == true &&
        report['synthetic_session_rejected'] == true) {
      code = 0;
    }
  } catch (error) {
    report['error_type'] = error.runtimeType.toString();
    if (error is FormatException) report['message'] = error.message;
    // This second probe only sends health, so stderr cannot contain account data.
    final probe =
        await Process.start(engine.executable, const [], runInShell: false);
    final output = probe.stdout.take(32).expand((chunk) => chunk).toList();
    final errors = probe.stderr.take(32).expand((chunk) => chunk).toList();
    probe.stdin.writeln('{"operation":"health"}');
    await probe.stdin.close();
    report['probe_exit'] = await probe.exitCode
        .timeout(const Duration(seconds: 30), onTimeout: () {
      probe.kill();
      return -1;
    });
    report['health_stdout'] = utf8.decode(await output, allowMalformed: true);
    report['health_stderr'] = utf8.decode(await errors, allowMalformed: true);
  }
  final directory = await Directory.systemTemp.createTemp('dd-music-check-');
  await File('${directory.path}/result.json').writeAsString(jsonEncode(report));
  return code;
}
