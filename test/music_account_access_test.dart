import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/importing/spotify_account_importer.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/connections/application/music_account_access.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'package:definitive_downloader/features/matching/music_engine.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';
import 'package:definitive_downloader/features/connections/domain/music_account.dart';
import 'package:definitive_downloader/features/connections/domain/deezer_login_policy.dart';
import 'package:definitive_downloader/features/connections/presentation/music_connection_actions.dart';
import 'package:definitive_downloader/features/connections/presentation/account_request_dialog.dart';
import 'package:definitive_downloader/features/connections/application/spotify_connection_controller.dart';
import 'spotify_fixtures.dart';

const playlist = 'https://open.spotify.com/playlist/1234567890123456789012';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('cancelar pedido Deezer não cancela uma restauração Spotify',
      (tester) async {
    final spotify = SpotifyConnectionController(
        store: MemorySpotifyStore(),
        authorization: FakeSpotifyFlow(),
        transport: FixtureSpotifyTransport((uri, method, headers, form) async =>
            throw StateError('Sem rede neste teste')))
      ..status = SpotifyConnectionStatus.restoring;
    final deezer = DeezerConnectionController(_SessionStore(), _LoginEngine());
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => AccountRequestDialog(
                            account: MusicAccount.deezer,
                            spotify: spotify,
                            deezer: deezer)),
                    child: const Text('Abrir'))))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(spotify.status, SpotifyConnectionStatus.restoring);
    await tester.pumpWidget(const SizedBox());
    spotify.dispose();
    deezer.dispose();
  });
  test(
      'verificação Deezer não grava sessão; somente login validado chega ao cofre',
      () async {
    final engine = _LoginEngine(), store = _SessionStore();
    final controller = DeezerConnectionController(store, engine);
    final synthetic = 'ownedFixture' * 16;
    expect(await controller.verifyLoginSession(synthetic), isFalse);
    expect(store.value, isNull);
    engine.accepted = true;
    expect(await controller.verifyLoginSession(synthetic), isTrue);
    expect(controller.connected, isFalse);
    expect(store.value, isNull);
    await controller.login(() async => null);
    expect(store.value, isNull);
    await controller.login(() async => synthetic);
    expect(controller.connected, isTrue);
    expect(store.value, synthetic);
    controller.dispose();
  });
  for (final decision in [
    MusicAccountDecision.cancelled,
    MusicAccountDecision.later
  ]) {
    test('pedido Deezer após Spotify: ${decision.name}', () async {
      final work = await Directory.systemTemp.createTemp('dd-account-gate-');
      final repository =
          LibraryRepository(AppDatabase('${work.path}/library.db'));
      await repository.database.initialize();
      var spotify = false, reads = 0;
      final access = MusicAccountAccess(
          spotifyConnected: () => spotify, deezerConnected: () => false);
      final calls = <MusicAccount>[];
      access.requestLogin = (account, {required allowLater}) async {
        calls.add(account);
        if (account == MusicAccount.spotify) {
          spotify = true;
          expect(allowLater, isFalse);
          return MusicAccountDecision.connected;
        }
        expect(allowLater, isTrue);
        return decision;
      };
      final engine = _LoginEngine();
      final deezer = DeezerConnectionController(_SessionStore(), engine);
      final controller = LibraryController(
          repository: repository,
          files: DesktopFiles(),
          spotify: const SpotifyImporter(BoundedHttp()),
          accounts: access,
          accountSpotify:
              SpotifyAccountImporter((path, {query = const {}}) async {
            reads++;
            if (path.endsWith('/items')) {
              return {
                'total': 1,
                'items': [
                  {
                    'item': {
                      'name': 'Faixa de teste',
                      'artists': [
                        {'name': 'Artista'}
                      ]
                    }
                  }
                ],
              };
            }
            return {
              'name': 'Playlist de teste',
              'items': {'total': 1}
            };
          }, () => spotify),
          music: MusicResolver(engine, deezer),
          csv: const CsvImporter(),
          catalog: const DeezerCatalog(BoundedHttp()),
          downloader: DownloadService(const BoundedHttp(), rootBundle));
      try {
        await controller.importPlaylist(playlist);
        await controller.preparationDone;
        expect(calls, [MusicAccount.spotify, MusicAccount.deezer]);
        expect(spotify, isTrue);
        expect(deezer.connected, isFalse);
        expect(engine.calls, 0);
        if (decision == MusicAccountDecision.later) {
          expect(reads, 2);
          final collection = (await repository.collections()).single;
          expect(collection.trackCount, 1);
          expect(await access.ensure(playlist), isTrue);
          expect(calls, hasLength(2));
        } else {
          expect(reads, 0);
          expect(await repository.collections(), isEmpty);
          expect(controller.message, contains('cancelada'));
        }
      } finally {
        controller.dispose();
        deezer.dispose();
        await work.delete(recursive: true);
      }
    });
  }
  test('adiar o Deezer não autoriza links que exigem essa conta', () async {
    final access = MusicAccountAccess(
        spotifyConnected: () => true, deezerConnected: () => false);
    final offers = <bool>[];
    access.requestLogin = (account, {required allowLater}) async {
      expect(account, MusicAccount.deezer);
      offers.add(allowLater);
      return allowLater
          ? MusicAccountDecision.later
          : MusicAccountDecision.cancelled;
    };
    expect(await access.ensure(playlist), isTrue);
    expect(await access.ensure('https://www.deezer.com/playlist/123'), isFalse);
    expect(offers, [true, false]);
  });
  test('Spotify seguido de Deezer, sem pedir novamente conexões existentes',
      () async {
    var spotify = false, deezer = false;
    final calls = <MusicAccount>[];
    final access = MusicAccountAccess(
        spotifyConnected: () => spotify, deezerConnected: () => deezer);
    access.requestLogin = (account, {required allowLater}) async {
      calls.add(account);
      if (account == MusicAccount.spotify) {
        spotify = true;
      } else {
        deezer = true;
      }
      return MusicAccountDecision.connected;
    };
    expect(await access.ensure(playlist), isTrue);
    expect(calls, [MusicAccount.spotify, MusicAccount.deezer]);
    expect(await access.ensure(playlist), isTrue);
    expect(calls.length, 2);
  });
  test(
      'cancelar Spotify não abre Deezer; não há importador anônimo alternativo',
      () async {
    final calls = <MusicAccount>[];
    final access = MusicAccountAccess(
        spotifyConnected: () => false, deezerConnected: () => false);
    access.requestLogin = (account, {required allowLater}) async {
      calls.add(account);
      return MusicAccountDecision.cancelled;
    };
    expect(await access.ensure(playlist), isFalse);
    expect(calls, [MusicAccount.spotify]);
    await expectLater(const SpotifyImporter(BoundedHttp()).open(playlist),
        throwsA(isA<MusicAccountRequired>()));
    calls.clear();
    await expectLater(
        access.ensure(
            'https://user:pass@open.spotify.com/playlist/1234567890123456789012'),
        throwsFormatException);
    expect(calls, isEmpty);
  });
  test('sessão só pode vir do domínio Deezer HTTPS, com valor válido', () {
    final value = 'a' * 192;
    expect(
        DeezerLoginPolicy.session(Uri.parse('https://www.deezer.com/'), value),
        value);
    for (final page in [
      'http://www.deezer.com/',
      'https://deezer.com.evil.test/',
      'https://accounts.google.com/',
      'https://u:p@www.deezer.com/'
    ]) {
      expect(DeezerLoginPolicy.session(Uri.parse(page), value), isNull);
    }
    expect(
        DeezerLoginPolicy.session(
            Uri.parse('https://www.deezer.com/'), 'short'),
        isNull);
    expect(DeezerLoginPolicy.allowNavigation(Uri.parse('file:///etc/passwd')),
        isFalse);
  });
  for (final width in [390.0, 1360.0]) {
    testWidgets('Fazer login depois cabe no diálogo a $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final spotify = SpotifyConnectionController(
          store: MemorySpotifyStore(),
          authorization: FakeSpotifyFlow(),
          transport: FixtureSpotifyTransport(
              (uri, method, headers, form) async =>
                  throw StateError('Sem rede neste teste')));
      final deezer =
          DeezerConnectionController(_SessionStore(), _LoginEngine());
      MusicAccountDecision? decision;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        decision = await showDialog<MusicAccountDecision>(
                            context: context,
                            builder: (_) => AccountRequestDialog(
                                account: MusicAccount.deezer,
                                spotify: spotify,
                                deezer: deezer,
                                allowLater: true));
                      },
                      child: const Text('Abrir'))))));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Entrar na Deezer'), findsOneWidget);
      await tester.tap(find.text('Fazer login depois'));
      await tester.pumpAndSettle();
      expect(decision, MusicAccountDecision.later);
      expect(deezer.connected, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      spotify.dispose();
      deezer.dispose();
    });
    testWidgets('ícones conectam e desaparecem a $width px', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var spotify = false, deezer = false;
      final changes = ValueNotifier(0);
      final access = MusicAccountAccess(
          spotifyConnected: () => spotify, deezerConnected: () => deezer);
      access.requestLogin = (account, {required allowLater}) async {
        if (account == MusicAccount.spotify) {
          spotify = true;
        } else {
          deezer = true;
        }
        changes.value++;
        return MusicAccountDecision.connected;
      };
      await tester.pumpWidget(MaterialApp(
          theme: appTheme(),
          home: Scaffold(
              body: ValueListenableBuilder(
                  valueListenable: changes,
                  builder: (context, revision, child) => MusicConnectionsScope(
                      access: access,
                      child: const MusicConnectionActions())))));
      await tester.tap(find.byTooltip('Entrar no Spotify · ampliar busca'));
      await tester.pump();
      expect(find.byTooltip('Entrar no Spotify · ampliar busca'), findsNothing);
      expect(
          find.byTooltip('Entrar no Deezer · ampliar busca'), findsOneWidget);
      await tester.tap(find.byTooltip('Entrar no Deezer · ampliar busca'));
      await tester.pump();
      expect(find.byType(IconButton), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      changes.dispose();
    });
  }
}

class _LoginEngine implements MusicEngine {
  bool accepted = false;
  int calls = 0;
  @override
  bool get available => true;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
      {DownloadCancellation? cancellation,
      void Function(String)? onStage,
      void Function(TransferProgress)? onProgress}) async {
    calls++;
    return {'connected': accepted};
  }
}

class _SessionStore implements DeezerSessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
