import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/library/presentation/track_row.dart';
import 'package:definitive_downloader/features/library/presentation/track_table.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/workspace/domain/download_columns.dart';
import 'package:definitive_downloader/features/workspace/presentation/download_table.dart';
import 'download_table_layout_test.dart' show entry;

void main() {
  for (final width in [1100.0, 390.0]) {
    testWidgets(
        '10 mil linhas prontas, widgets virtuais e scroll até o fim a $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rows = List.generate(10000, (i) => entry(i + 1));
      final library = LibraryController(
          repository: const LibraryRepository(AppDatabase('unused')),
          files: DesktopFiles(),
          spotify: const SpotifyImporter(BoundedHttp()),
          csv: const CsvImporter(),
          catalog: const DeezerCatalog(BoundedHttp()),
          downloader: DownloadService(const BoundedHttp(), rootBundle));
      library.current = const Collection(
          id: 1,
          name: 'Grande',
          source: 'Fixture',
          sourceUrl: '',
          trackCount: 10000,
          completedCount: 0,
          isPartial: false);
      library.page = TrackPage(rows.map((e) => e.track).toList(), 10000, 0);
      addTearDown(library.dispose);
      await tester.pumpWidget(MaterialApp(
          theme: appTheme(),
          home: Scaffold(
              body: TrackTable(controller: library, onFocus: (_) {}))));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Próxima página'), findsNothing);
      expect(find.byType(TrackRow).evaluate().length, lessThan(30));
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.childrenDelegate.estimatedChildCount, 10000);
      list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('track-row-10000')), findsOneWidget);
      expect(find.byKey(const ValueKey('track-row-1')), findsNothing);
      expect(find.byType(TrackRow).evaluate().length, lessThan(30));
      final visibleChecks = <List<int>>[];
      await tester.pumpWidget(MaterialApp(
          theme: appTheme(),
          home: Scaffold(
              body: DownloadTable(
                  entries: rows,
                  widths: downloadColumns.map((c) => c.width).toList(),
                  onResize: (_) {},
                  onResizeEnd: () {},
                  selection: const {},
                  onSelect: (_, __) {},
                  onSelectPage: (_) {},
                  output: '',
                  onVisible: visibleChecks.add))));
      await tester.pumpAndSettle();
      final downloads =
          tester.widget<ListView>(find.byKey(const ValueKey('download-rows')));
      expect(downloads.childrenDelegate.estimatedChildCount, 10000);
      expect(visibleChecks.expand((ids) => ids).toSet().length, lessThan(30));
      downloads.controller!
          .jumpTo(downloads.controller!.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('download-row-10000')), findsOneWidget);
      expect(find.byKey(const ValueKey('download-row-1')), findsNothing);
      expect(visibleChecks.last, contains(10000));
      expect(visibleChecks.expand((ids) => ids).toSet().length, lessThan(60));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
