import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/platform/android_incoming.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/application/shared_music_links.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/presentation/incoming_music_host.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'collection_composition_test.dart' show LocalInspectorFixture;
import 'playlist_matching_test.dart' show FixturePlaylist;
import 'widget_io.dart';

class _Inbox extends AndroidIncoming {
  _Inbox(this.item);
  IncomingMusic? item;
  final finished = <String>[];
  @override
  Future<IncomingMusic?> peek() async => item;
  @override
  Future<void> finish(String id) async {
    finished.add(id);
    item = null;
  }
}

class _Files extends DesktopFiles {
  _Files(this.output);
  final String output;
  @override
  Future<String> defaultOutputDirectory() async => output;
}

void main() {
  test('texto compartilhado extrai URLs e conserva repetição', () {
    expect(
        sharedMusicLinks(
            'Ouça (https://soundcloud.com/artist/song).\nhttps://soundcloud.com/artist/song'),
        'https://soundcloud.com/artist/song\nhttps://soundcloud.com/artist/song');
    expect(sharedMusicLinks('sem link'), 'sem link');
  });
  for (final local in [false, true]) {
    testWidgets(
        local
            ? 'MP3 recebido cria cópia somente após adicionar'
            : 'cancelar link recebido não altera biblioteca', (tester) async {
      late Directory temp;
      late LibraryController library;
      late String original;
      await tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp('dd-incoming-');
        original = (await File('assets/demo/tone.mp3')
                .copy('${temp.path}/original.mp3'))
            .path;
        library = LibraryController(
            repository: LibraryRepository(AppDatabase('${temp.path}/db')),
            files: _Files('${temp.path}/output'),
            spotify: FixturePlaylist([]),
            csv: const CsvImporter(),
            localInspector: LocalInspectorFixture(),
            catalog: const DeezerCatalog(BoundedHttp()),
            downloader: DownloadService(const BoundedHttp(), rootBundle));
        await library.initialize();
      });
      final inbox = _Inbox(IncomingMusic(
          'receipt',
          local ? '' : 'Título https://example.org/audio.mp3',
          local ? [original] : [],
          ''));
      addTearDown(() async {
        inbox.dispose();
        library.dispose();
        await temp.delete(recursive: true);
      });
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: IncomingMusicHost(
                  incoming: inbox,
                  library: library,
                  child: const Text('Biblioteca')))));
      await tester.pump(const Duration(milliseconds: 400));
      await ioUntil(tester,
          () => find.text('Recebido de outro app').evaluate().isNotEmpty);
      expect(library.collections, isEmpty);
      expect(library.downloading, isFalse);
      if (local) {
        await tester.enterText(find.byType(TextField).first, 'Recebidas');
        await tester.tap(find.text('Adicionar'));
      } else {
        expect(
            tester
                .widget<TextField>(
                    find.byKey(const ValueKey('extra-music-links')))
                .controller!
                .text,
            'https://example.org/audio.mp3');
        await tester.tap(find.text('Cancelar'));
      }
      await ioUntil(tester, () => inbox.finished.isNotEmpty);
      await tester.runAsync(() async {
        expect(await File(original).exists(), isTrue);
        if (local) {
          expect(library.collections.single.completedCount, 1);
          final tracks = await library.repository
              .completedPage(library.collections.single.id, 0);
          expect(tracks.single.localPath, isNot(original));
          expect(await File(tracks.single.localPath).readAsBytes(),
              await File(original).readAsBytes());
        } else {
          expect(library.collections, isEmpty);
        }
      });
      expect(library.downloading, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
