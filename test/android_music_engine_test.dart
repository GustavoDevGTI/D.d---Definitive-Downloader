import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/features/matching/android_music_engine.dart';
import 'package:definitive_downloader/features/downloads/download_cancellation.dart';
import 'package:definitive_downloader/features/downloads/transfer_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final binding =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  const health = {
    'ready': true,
    'protocol': 1,
    'platform': 'android',
    'codecValidated': true,
    'blockVectorValidated': true
  };
  Future<void> event(String id, Map<String, Object> value) async {
    await binding.handlePlatformMessage(
        AndroidMusicEngine.channel.name,
        const StandardMethodCodec().encodeMethodCall(
            MethodCall('event', {'id': id, 'line': jsonEncode(value)})),
        (_) {});
  }

  setUp(calls.clear);
  tearDown(
      () => binding.setMockMethodCallHandler(AndroidMusicEngine.channel, null));

  test(
      'capacidade exige runtime Android e codecs validados, não só health genérico',
      () async {
    binding.setMockMethodCallHandler(AndroidMusicEngine.channel,
        (_) async => jsonEncode({'ready': true, 'protocol': 1}));
    expect((await AndroidMusicEngine.installed()).available, isFalse);
  });

  test('protocolo mantém estágios/bytes por operação e ignora ID antigo',
      () async {
    final progress = <TransferProgress>[];
    final stages = <String>[];
    binding.setMockMethodCallHandler(AndroidMusicEngine.channel, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      if (call.method == 'run' &&
          (jsonDecode(args['request']) as Map)['operation'] == 'health') {
        return jsonEncode(health);
      }
      await event('old-id', {'event': 'stage', 'message': 'antigo'});
      await event(args['id'], {'event': 'stage', 'message': 'Recebendo áudio'});
      await event(args['id'], {
        'event': 'progress',
        'received': 2000,
        'total': 10000,
        'bytesPerSecond': 200
      });
      return jsonEncode({'candidates': []});
    });
    final engine = await AndroidMusicEngine.installed();
    expect(engine.available, isTrue);
    await engine.call({'operation': 'search', 'query': 'faixa'},
        onStage: stages.add, onProgress: progress.add);
    expect(stages, ['Recebendo áudio']);
    expect(progress.single.remaining, const Duration(seconds: 40));
  });

  test(
      'cancelamento nativo conserva DownloadCancelled e limita pausa à operação',
      () async {
    final pending = Completer<String>();
    final token = DownloadCancellation();
    binding.setMockMethodCallHandler(AndroidMusicEngine.channel, (call) async {
      calls.add(call);
      final args = Map<String, dynamic>.from(call.arguments as Map);
      if (call.method == 'run') {
        if ((jsonDecode(args['request']) as Map)['operation'] == 'health') {
          return jsonEncode(health);
        }
        return pending.future;
      }
      if (args['control'] == 'cancel' && !pending.isCompleted) {
        pending.completeError(
            PlatformException(code: 'music', message: 'interrompido'));
      }
      return null;
    });
    final engine = await AndroidMusicEngine.installed();
    token.pauseMode = true;
    final response =
        engine.call({'operation': 'download'}, cancellation: token);
    final checked = expectLater(response, throwsA(isA<DownloadCancelled>()));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    token.cancelled = true;
    await checked;
    expect(
        calls
            .where((c) => c.method == 'control')
            .map((c) => (c.arguments as Map)['control']),
        ['pause', 'cancel']);
    final ids = calls
        .where((c) => c.method == 'control')
        .map((c) => (c.arguments as Map)['id'])
        .toSet();
    expect(ids.length, 1);
  });

  test('progresso inválido interrompe o protocolo em vez de aceitar conclusão',
      () async {
    binding.setMockMethodCallHandler(AndroidMusicEngine.channel, (call) async {
      if (call.method != 'run') return null;
      final args = Map<String, dynamic>.from(call.arguments as Map);
      if ((jsonDecode(args['request']) as Map)['operation'] == 'health') {
        return jsonEncode(health);
      }
      await event(args['id'], {'event': 'progress', 'received': -1});
      return jsonEncode({'path': '/fixture/not-a-download'});
    });
    final engine = await AndroidMusicEngine.installed();
    await expectLater(engine.call({'operation': 'download'}),
        throwsA(isA<FormatException>()));
  });
}
