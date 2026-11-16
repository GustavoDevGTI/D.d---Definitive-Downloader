import 'package:definitive_downloader/core/platform/android_files.dart';
import 'package:definitive_downloader/core/platform/android_documents.dart';
import 'package:definitive_downloader/core/platform/platform_services.dart';
import 'package:definitive_downloader/features/player/data/android_audio_engine.dart';
import 'package:definitive_downloader/features/player/domain/playback.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            AndroidDocuments.channel,
            (call) async => switch (call.method) {
                  'destinations' => [],
                  'playback' => (call.arguments as Map)['uri'],
                  _ => null,
                });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidFiles.channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'defaultOutput' => '/storage/app/media',
        'pickFiles' => ['/cache/imports/song.mp3'],
        'chooseOutput' => null,
        _ => null,
      };
    });
  });
  tearDown(() {
    final binding =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    binding.setMockMethodCallHandler(AndroidFiles.channel, null);
    binding.setMockMethodCallHandler(AndroidDocuments.channel, null);
  });

  test('seletor Android entrega cópias por caminho e conserva cancelamento',
      () async {
    final files = AndroidFiles();
    expect(await files.defaultOutputDirectory(), '/storage/app/media');
    expect(await files.chooseMp3Files(), ['/cache/imports/song.mp3']);
    expect(calls.last.arguments, {'kind': 'mp3'});
    expect(await files.choosePlaylistFile(), '/cache/imports/song.mp3');
    expect(calls.last.arguments, {'kind': 'playlist'});
    await files.releasePlaylistFile('/cache/imports/song.mp3');
    expect(calls.last.method, 'releasePlaylistFile');
    await files.chooseCover();
    expect(calls.last.arguments, {'kind': 'cover'});
    expect(await files.chooseOutput(), isNull);
  });

  test('motor ausente recusa operação sem simular transferência', () async {
    const engine = UnavailableMusicEngine();
    expect(engine.available, isFalse);
    expect(engine.call({'operation': 'download'}),
        throwsA(isA<FormatException>()));
  });
  test('pasta Android usa navegador nativo sem converter URI em caminho',
      () async {
    await AndroidFiles().openFolder('/storage/app/media');
    expect(calls.single.method, 'openFolder');
    expect(calls.single.arguments, {'path': '/storage/app/media'});
  });
  test('player Android publica progresso/fim sem callbacks após descarte',
      () async {
    final binding =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    binding.setMockMethodCallHandler(
        AndroidAudioEngine.channel, (_) async => null);
    final engine = AndroidAudioEngine();
    final events = <AudioEvent>[];
    final subscription = engine.events.listen(events.add);
    Future<void> event(Map<String, Object> value) async {
      await binding.handlePlatformMessage(
          AndroidAudioEngine.channel.name,
          const StandardMethodCodec()
              .encodeMethodCall(MethodCall('event', value)),
          (_) {});
      await Future<void>.delayed(Duration.zero);
    }

    await event({'playing': true, 'durationMs': 4000, 'positionMs': 1200});
    expect(events.single.position, const Duration(milliseconds: 1200));
    await event({'playing': false, 'completed': true});
    expect(events.last.completed, isTrue);
    await engine.volume(.4);
    expect(engine.measurements['volume'], 40);
    await engine.dispose();
    expect(engine.available, isFalse);
    await event({'failed': true});
    expect(events.length, 2);
    await subscription.cancel();
    binding.setMockMethodCallHandler(AndroidAudioEngine.channel, null);
  });
}
