import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:definitive_downloader/features/matching/android_music_engine.dart';
import 'package:definitive_downloader/features/matching/music_candidates.dart';
import 'package:definitive_downloader/features/player/data/android_audio_engine.dart';
import 'package:definitive_downloader/features/player/data/audio_tags.dart';

// Explicit live checks, never part of the offline/essential test profile.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late AndroidMusicEngine engine;
  const live = bool.fromEnvironment('DD_ANDROID_LIVE_SOURCES');
  setUpAll(() async {
    if (!live) return;
    engine = await AndroidMusicEngine.installed();
    expect(engine.available, isTrue, reason: engine.initializationError);
  });
  for (final provider in ['deezerFull', 'youtubeMusic', 'soundcloud']) {
    testWidgets('busca pública Android: $provider', (tester) async {
      final response = await engine.call({
        'operation': 'search',
        'provider': provider,
        'query': provider == 'soundcloud'
            ? 'The Concept D D Dance'
            : 'LEAP Sick Sense'
      });
      final rows = (response['candidates'] as List).cast<Map>();
      expect(rows, isNotEmpty);
      for (final row in rows) {
        final candidate = parseMusicCandidate(Map<String, dynamic>.from(row));
        expect(candidate.kind.name, provider);
        expect(candidate.title, isNotEmpty);
      }
      debugPrint('ANDROID_PUBLIC_SEARCH ${jsonEncode({
            'provider': provider,
            'count': rows.length
          })}');
    }, skip: !live, timeout: const Timeout(Duration(minutes: 2)));
  }
  testWidgets('YouTube Music Android: áudio de catálogo completo',
      (tester) async {
    final response = await engine.call({
      'operation': 'search',
      'provider': 'youtubeMusic',
      'query': 'LEAP Sick Sense'
    });
    final rows = (response['candidates'] as List).cast<Map>();
    final candidate = Map<String, dynamic>.from(rows.firstWhere((row) =>
        row['title'].toString().toLowerCase() == 'sick sense' &&
        row['artist'].toString().toLowerCase() == 'leap'));
    final directory =
        await (await getTemporaryDirectory()).createTemp('dd-ytm-native-');
    addTearDown(() => directory.delete(recursive: true));
    var measurements = 0;
    final result = await engine.call({
      'operation': 'download',
      'candidate': candidate,
      'authorization': 'catalog',
      'directory': directory.path,
      'outputTitle': ''
    }, onProgress: (_) => measurements++);
    expect(result['decoded'], isTrue);
    expect(result['coverEmbedded'], isTrue);
    expect((result['actual'] as Map)['pageUrl'], candidate['pageUrl']);
    final path = result['path'] as String;
    expect(await File(path).parent.resolveSymbolicLinks(),
        await directory.resolveSymbolicLinks());
    final tags = await readAudioTags(path);
    expect(tags.title, isNotEmpty);
    expect(tags.cover, isNotNull);
    final inspected = await AndroidAudioEngine.channel
        .invokeMapMethod<String, dynamic>('inspect', {'path': path});
    expect(
        ((inspected!['durationMs'] as int) - (candidate['durationMs'] as int))
            .abs(),
        lessThanOrEqualTo(2000));
    expect(measurements, greaterThan(0));
    debugPrint('ANDROID_YTM_RESULT ${jsonEncode({
          'decoded': true,
          'cover': true,
          'bytes': await File(path).length(),
          'progressEvents': measurements,
          'accountUsed': false
        })}');
  }, skip: !live, timeout: const Timeout(Duration(minutes: 5)));
}
