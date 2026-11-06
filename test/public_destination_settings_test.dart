import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/workspace/presentation/settings_workspace.dart';
import 'playlist_matching_test.dart' show FixturePlaylist;

class _PublicFiles extends DesktopFiles {
  int revoked = 0;
  @override
  bool publicDestination(String path) => true;
  @override
  String displayPath(String path) => 'Pasta pública / Music';
  @override
  Future<void> revokeDestination(String path) async {
    revoked++;
  }
}

void main() {
  testWidgets(
      'pasta pública mostra destino legível e revoga somente após confirmação no celular',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final files = _PublicFiles();
    final controller = LibraryController(
        repository: LibraryRepository(const AppDatabase('unused')),
        files: files,
        spotify: FixturePlaylist([]),
        csv: const CsvImporter(),
        downloader: DownloadService(const BoundedHttp(), rootBundle),
        catalog: const DeezerCatalog(BoundedHttp()));
    controller.outputDirectory = '/private/anchor';
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: appTheme(),
        home: Scaffold(
            body: SettingsWorkspace(
                controller: controller, onConnections: null))));
    await tester.tap(find.text('Pasta padrão de downloads'));
    await tester.pumpAndSettle();
    expect(find.text('Pasta pública / Music'), findsOneWidget);
    expect(find.text('/private/anchor'), findsNothing);
    await tester.tap(find.text('Revogar acesso'));
    await tester.pumpAndSettle();
    expect(files.revoked, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Revogar acesso'));
    await tester.pumpAndSettle();
    expect(files.revoked, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
