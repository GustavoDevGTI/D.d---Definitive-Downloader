import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/player/application/music_player_controller.dart';
import 'package:definitive_downloader/features/player/presentation/player_scope.dart';
import 'package:definitive_downloader/features/player/presentation/listening_actions.dart';
import 'player_fixtures.dart';

void main() {
  for (final width in [900.0, 390.0]) {
    testWidgets('escuta alinhada e apenas interna a ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final player = MusicPlayerController(
          MemoryPlayerLibrary(), FakeAudioEngine(), PlayerFiles());
      addTearDown(player.dispose);
      final output = Platform.environment['DD_LAYOUT_OUTPUT'];
      if (output != null) {
        await (FontLoader('Manrope')
              ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
            .load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
      }
      final key = GlobalKey();
      Future<void> render(Candidate? candidate) async {
        await tester.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: appTheme(),
                home: PlayerScope(
                    player: player,
                    child: Scaffold(
                        body: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Conferência'),
                                  ListeningActions(
                                      track: audioTrack(path: ''),
                                      candidate: candidate)
                                ])))))));
        await tester.pumpAndSettle();
      }

      await render(audioCandidate());
      final listen = tester.getRect(find.text('Ouvir prévia'));
      final icon = tester.getRect(find.byIcon(Icons.open_in_new_rounded));
      expect((listen.center.dy - icon.center.dy).abs(), lessThan(1));
      final button = tester.getRect(find.byType(TextButton));
      expect(button.left, 16);
      if (output != null) {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File('$output/listen-${width.toInt()}.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await render(const Candidate(
          title: 'Faixa exata',
          artist: 'Pessoa',
          album: '',
          durationMs: 180000,
          pageUrl: 'https://music.youtube.com/watch?v=abcdefghijk',
          previewUrl: '',
          coverUrl: '',
          kind: SourceKind.youtubeMusic));
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.textContaining('Ouvir'), findsNothing);
      expect(find.byTooltip('Abrir referência'), findsOneWidget);
      expect(find.byTooltip('Copiar link'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
