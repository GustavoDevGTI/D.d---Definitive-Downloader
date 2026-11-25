import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/audio_conversion/application/local_audio_converter.dart';
import 'package:definitive_downloader/features/audio_conversion/presentation/audio_conversion_dialog.dart';
import 'package:definitive_downloader/features/downloads/download_cancellation.dart';
import 'package:definitive_downloader/features/importing/local_media_importer.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/organization/data/collection_organization_repository.dart';
import 'package:definitive_downloader/features/player/data/audio_tags.dart';
import 'package:definitive_downloader/features/player/data/player_library.dart';
import 'package:definitive_downloader/features/player/data/media_kit_engine.dart';
import 'collection_composition_test.dart' show LocalInspectorFixture;

class _NoDestination extends DesktopFiles {
  @override
  Future<String?> chooseMp3Destination(String suggestedName) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late LibraryRepository library;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('dd-local-formats-');
    library = LibraryRepository(AppDatabase('${root.path}/library.db'));
    await library.database.initialize();
  });
  tearDown(() => root.delete(recursive: true));

  test(
      'arquivos avulsos de formatos mistos conservam extensão, cópia e prioridade local',
      () async {
    final id = await CollectionOrganizationRepository(library.database)
        .create('Mistura');
    final inputs = <String>[];
    for (final extension in [
      '.flac',
      '.wav',
      '.m4a',
      '.ogg',
      '.wma',
      '.aiff',
      '.opus'
    ]) {
      final file = File('${root.path}/Entrada$extension');
      await file
          .writeAsBytes(List.filled(128, 17)); // IO fixture, decoder injected.
      inputs.add(file.path);
    }
    await LocalMediaImporter(library, inspector: LocalInspectorFixture()).add(
        id, inputs, '${root.path}/output',
        cancellation: DownloadCancellation());
    final rows = (await library.page(id)).items;
    expect(rows.map((t) => t.position), [1, 2, 3, 4, 5, 6, 7]);
    for (var i = 0; i < rows.length; i++) {
      expect(rows[i].sourceKind, SourceKind.localFile);
      expect(rows[i].status, TrackStatus.completed);
      expect(rows[i].localPath, isNot(inputs[i]));
      expect(await File(rows[i].localPath).readAsBytes(),
          await File(inputs[i]).readAsBytes());
      expect(
          await PlayerLibrary(library.database).localFor(rows[i]), isNotNull);
    }
    expect((await PlayerLibrary(library.database).collection(id)).length, 7);
  });

  test('conversão recusa sobrescrever e cancelamento preserva originais',
      () async {
    final source = File('${root.path}/original.flac');
    final destination = File('${root.path}/existing.mp3');
    await source.writeAsBytes(List.filled(128, 23));
    await destination.writeAsString('conteúdo anterior');
    final converter = LocalAudioConverter(inspector: LocalInspectorFixture());
    await expectLater(
        converter.convert(source.path, destination.path,
            cancellation: DownloadCancellation()),
        throwsFormatException);
    expect(await destination.readAsString(), 'conteúdo anterior');
    await expectLater(
        converter.convert(source.path, '${root.path}/cancelled.mp3',
            cancellation: DownloadCancellation()..cancelled = true),
        throwsA(isA<DownloadCancelled>()));
    expect(await File('${root.path}/cancelled.mp3').exists(), isFalse);
    expect(await source.readAsBytes(), List.filled(128, 23));
  });

  test('metadados FLAC leem comentários limitados sem modificar o áudio',
      () async {
    List<int> word(int value) =>
        (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();
    final comments = ['TITLE=Canção de teste', 'ARTIST=Pessoa', 'ALBUM=DVD'];
    final block = BytesBuilder()
      ..add(word(0))
      ..add(word(comments.length));
    for (final comment in comments) {
      final bytes = utf8.encode(comment);
      block
        ..add(word(bytes.length))
        ..add(bytes);
    }
    final bytes = block.takeBytes();
    final data = <int>[
      102,
      76,
      97,
      67,
      132,
      bytes.length >> 16,
      (bytes.length >> 8) & 255,
      bytes.length & 255,
      ...bytes
    ];
    final file = await File('${root.path}/tags.flac').writeAsBytes(data);
    final tags = await readAudioTags(file.path);
    expect(tags.title, 'Canção de teste');
    expect(tags.artist, 'Pessoa');
    expect(tags.album, 'DVD');
    expect(await file.readAsBytes(), data);
  });

  test('capa FLAC limitada e bloco truncado não quebram a leitura', () async {
    final image = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');
    List<int> word(int value) =>
        (ByteData(4)..setUint32(0, value)).buffer.asUint8List();
    final picture = <int>[
      ...word(3),
      ...word(9),
      ...ascii.encode('image/png'),
      ...word(0),
      ...word(1),
      ...word(1),
      ...word(32),
      ...word(0),
      ...word(image.length),
      ...image
    ];
    final data = <int>[102, 76, 97, 67, 134, 0, 0, picture.length, ...picture];
    final file = await File('${root.path}/cover.flac').writeAsBytes(data);
    expect((await readAudioTags(file.path)).cover, image);
    await file.writeAsBytes(data.sublist(0, data.length - 4));
    expect((await readAudioTags(file.path)).cover, isNull);
  });

  for (final width in [390.0, 900.0]) {
    testWidgets('conversor cabe e cancelar o seletor não converte a $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final id = (await tester.runAsync(() => library.importCollection(
          ImportedCollection(
              name: 'Local',
              source: 'Local',
              sourceUrl: '',
              tracks: Stream.value(const TrackDraft(
                  title: 'Arquivo FLAC', artist: 'Pessoa'))))))!;
      final track =
          (await tester.runAsync(() => library.page(id)))!.items.single;
      await tester.pumpWidget(MaterialApp(
          theme: appTheme(platform: TargetPlatform.windows),
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () =>
                          showAudioConversion(context, track, _NoDestination()),
                      child: const Text('Converter'))))));
      await tester.tap(find.text('Converter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar MP3'));
      await tester.pumpAndSettle();
      expect(find.text('Salvar MP3'), findsOneWidget);
      expect(find.text('MP3 salvo'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  }

  test('fixtures sintéticas: decoder, importação e FLAC multicanal para MP3',
      () async {
    final ffmpeg = Platform.environment['DD_SYNTHETIC_AUDIO_FFMPEG']!;
    mk.MediaKit.ensureInitialized(
        libmpv: Platform.environment['DD_SYNTHETIC_AUDIO_MPV']);
    final inputs = <String>[];
    for (final format in {
      'flac': 'flac',
      'wav': 'pcm_s24le',
      'm4a': 'aac',
      'ogg': 'libvorbis',
      'opus': 'libopus',
      'wma': 'wmav2',
      'aiff': 'pcm_s16be',
    }.entries) {
      final input = '${root.path}/synth.${format.key}';
      final result = await Process.run(ffmpeg, [
        '-nostdin',
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        format.key == 'flac'
            ? 'anullsrc=r=96000:cl=5.1'
            : 'anullsrc=r=48000:cl=stereo',
        '-t',
        '0.8',
        '-c:a',
        format.value,
        if (format.key == 'flac') ...['-sample_fmt', 's32'],
        '-metadata',
        'title=Faixa sintética',
        '-metadata',
        'artist=Pessoa',
        input
      ]);
      expect(result.exitCode, 0, reason: '${format.key}: ${result.stderr}');
      inputs.add(input);
    }
    final id = await CollectionOrganizationRepository(library.database)
        .create('Sintéticos');
    await LocalMediaImporter(library).add(id, inputs, '${root.path}/output',
        cancellation: DownloadCancellation());
    final rows = (await library.page(id)).items;
    expect(rows.length, inputs.length);
    expect(rows.first.title, 'Faixa sintética');
    expect(rows.first.artist, 'Pessoa');
    final engine = MediaKitEngine();
    try {
      await engine.volume(0);
      for (final row in rows) {
        final advanced = engine.events
            .firstWhere((event) =>
                event.position != null && event.position! > Duration.zero)
            .timeout(const Duration(seconds: 10));
        await engine.open(Uri.file(row.localPath).toString());
        await advanced;
        await engine.stop();
      }
    } finally {
      await engine.dispose();
    }
    final digest = sha256.convert(await File(inputs.first).readAsBytes());
    final destination = '${root.path}/converted.mp3';
    await LocalAudioConverter(ffmpeg: ffmpeg).convert(inputs.first, destination,
        cancellation: DownloadCancellation());
    expect(await File(destination).length(), greaterThan(1000));
    expect((await readAudioTags(destination)).title, 'Faixa sintética');
    expect(sha256.convert(await File(inputs.first).readAsBytes()), digest);
    expect(
        (await library.page(id)).items.first.localPath, rows.first.localPath);
    expect((await library.page(id)).total, inputs.length);
  },
      skip: Platform.environment['DD_SYNTHETIC_AUDIO_FFMPEG'] == null,
      timeout: const Timeout(Duration(minutes: 3)));
}
