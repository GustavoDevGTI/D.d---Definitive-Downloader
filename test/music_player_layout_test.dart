import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/features/player/application/music_player_controller.dart';
import 'package:definitive_downloader/features/player/presentation/player_bar.dart';
import 'package:definitive_downloader/features/player/presentation/audio_slider.dart';
import 'package:definitive_downloader/features/player/presentation/player_scope.dart';
import 'package:definitive_downloader/features/player/presentation/listening_actions.dart';
import 'player_fixtures.dart';

void main() {
  for (final size in [
    (1360.0, 1.0),
    (900.0, 1.0),
    (390.0, 1.0),
    (320.0, 2.0)
  ]) {
    testWidgets('player responsivo em ${size.$1}px, texto ${size.$2}',
        (tester) async {
      tester.view.physicalSize = Size(size.$1, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (Platform.environment['DD_PLAYER_SCREENSHOTS'] != null) {
        await (FontLoader('Manrope')
              ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
            .load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
      }
      final engine = FakeAudioEngine();
      final player =
          MusicPlayerController(MemoryPlayerLibrary(), engine, PlayerFiles());
      addTearDown(player.dispose);
      await player.playCollection(1);
      final boundary = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: appTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(size.$2)),
              child: child!),
          home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                  body: Column(children: [
                const Expanded(child: Center(child: Text('Coleção'))),
                PlayerBar(player: player)
              ])))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('player-play-pause')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('player-play-pause')));
      await tester.pumpAndSettle();
      expect(player.playing, isFalse);
      await tester.tap(find.byTooltip('Próxima faixa'));
      await tester.pumpAndSettle();
      expect(player.index, 1);
      if (size.$1 >= 780) {
        final volume = tester
            .widget<AudioSlider>(find.byKey(const ValueKey('player-volume')));
        volume.onChanged!(.437);
        volume.onChangeEnd!(.437);
        await tester.pumpAndSettle();
        expect(player.volume, .437);
        await tester.tap(find.byTooltip('Fila de reprodução'));
        await tester.pumpAndSettle();
        expect(find.text('Fila de reprodução · 4'), findsOneWidget);
        await tester.tap(find.byTooltip('Fechar fila'));
      } else {
        await tester.tap(find.text(player.title));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('player-volume')), findsOneWidget);
        expect(find.byTooltip('Ativar aleatório'), findsOneWidget);
        expect(find.byTooltip('Repetição desativada'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Fechar player'));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final output = Platform.environment['DD_PLAYER_SCREENSHOTS'];
      if (output != null) {
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes =
              (await image.toByteData(format: ui.ImageByteFormat.png))!;
          await File('$output/player-${size.$1.toInt()}.png')
              .writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
      'ouvir uma candidata não seleciona nem confirma versão; referência é exata',
      (tester) async {
    final engine = FakeAudioEngine();
    final files = PlayerFiles();
    final player = MusicPlayerController(MemoryPlayerLibrary(), engine, files);
    addTearDown(player.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: appTheme(),
        home: PlayerScope(
            player: player,
            child: Scaffold(
                body: ListeningActions(
                    track: audioTrack(path: ''),
                    candidate: audioCandidate())))));
    await tester.tap(find.text('Ouvir prévia'));
    await tester.pumpAndSettle();
    expect(player.current!.isPreview, isTrue);
    expect(engine.opens, ['https://cdn.test.dzcdn.net/p.mp3']);
    expect(files.opened, isEmpty);
    await tester.tap(find.byTooltip('Abrir referência'));
    await tester.pumpAndSettle();
    expect(files.opened.single.toString(), 'https://www.deezer.com/track/123');
    final accept = tester.widget<IconButton>(find.byWidgetPredicate((widget) =>
        widget is IconButton && widget.tooltip == 'Usar esta versão'));
    expect(accept.onPressed,
        isNull); // No review controller: listening alone is insufficient.
  });
}
