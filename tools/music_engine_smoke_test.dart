// Explicit packaged-worker check. Uses only a synthetic, invalid session.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/features/matching/music_engine.dart';

void main() {
  final executable = Platform.environment['DD_SMOKE_WORKER'];
  test('packaged worker returns health and a sanitized account rejection',
      () async {
    final engine = WindowsMusicEngine(executable!);
    expect((await engine.call({'operation': 'health'}))['ready'], true);
    await expectLater(
        engine.call({'operation': 'deezerConnect', 'arl': 'a' * 192}),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            contains('expirou ou não foi autorizada'))));
  }, skip: executable == null, timeout: const Timeout(Duration(seconds: 90)));
}
