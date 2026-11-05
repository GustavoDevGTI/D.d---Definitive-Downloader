import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/features/library/presentation/artwork_thumbnail.dart';
import 'package:definitive_downloader/features/library/data/artwork_store.dart';
import 'package:definitive_downloader/features/downloads/mp3_tags.dart';
import 'support.dart';

class ArtworkHttp extends BoundedHttp {
  int calls = 0;
  bool fail = true;
  Completer<Uint8List>? delayed;
  @override
  Future<Uint8List> bytes(Uri uri, {int maximumBytes = 2097152}) async {
    calls++;
    if (fail) throw const FormatException('Falha transitória');
    if (delayed != null) return delayed!.future;
    return (await rootBundle.load('assets/demo/cover.png'))
        .buffer
        .asUint8List();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'capa incorporada é lida sem capturar o cache no isolate e reutilizada no scroll',
      (tester) async {
    await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('dd-embedded-cover-');
      try {
        final file = File('${temp.path}/music.mp3');
        final cover = await File('assets/demo/cover.png').readAsBytes();
        await const Mp3TagWriter().write(
            source: File('assets/demo/tone.mp3'),
            destination: file,
            track: testTrack(),
            cover: cover);
        final store = ArtworkStore();
        final bytes = await store.load('', audioPath: file.path);
        expect(bytes, isNotNull);
        expect(store.cached('', audioPath: file.path), same(bytes));
        expect(await store.load('', audioPath: file.path), same(bytes));
      } finally {
        await temp.delete(recursive: true);
      }
    });
  });
  testWidgets(
      'falha transitória não apaga capa em cache nem impede nova tentativa',
      (tester) async {
    var clock = DateTime(2026);
    final http = ArtworkHttp();
    final store = ArtworkStore(http: http, now: () => clock);
    const url = 'https://cover.example/one.png';
    await tester.runAsync(() async {
      expect(await store.load(url), isNull);
      http.fail = false;
      expect(await store.load(url), isNull);
      expect(http.calls, 1);
      clock = clock.add(const Duration(seconds: 6));
      expect(await store.load(url), isNotNull);
      expect(store.cached(url), isNotNull);
    });
    await tester.pumpWidget(
        MaterialApp(home: ArtworkThumbnail(reference: url, store: store)));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
        MaterialApp(home: ArtworkThumbnail(reference: url, store: store)));
    expect(find.byType(Image), findsOneWidget,
        reason:
            'Capa conhecida aparece já no primeiro quadro, sem piscar ao voltar no scroll');
    expect(http.calls, 2);
    http.delayed = Completer<Uint8List>();
    await tester.pumpWidget(MaterialApp(
        home: ArtworkThumbnail(
            reference: 'https://cover.example/two.png', store: store)));
    await tester.pump();
    expect(find.byType(Image), findsNothing,
        reason: 'Nunca mostrar a capa da faixa anterior em linha reciclada');
    final bytes =
        (await rootBundle.load('assets/demo/cover.png')).buffer.asUint8List();
    await tester.runAsync(() async {
      http.delayed!.complete(bytes);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('capa é copiada, limitada e independente da imagem original',
      (tester) async {
    await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('dd-cover-');
      try {
        final source = File('${temp.path}/original.png');
        await File('assets/demo/cover.png').copy(source.path);
        final store = ArtworkStore();
        final path = await store.importCover(source.path, temp.path);
        expect(path, contains('playlist-covers'));
        expect(await store.importCover(source.path, temp.path), path);
        await source.delete();
        final bytes = await store.load(path);
        expect(bytes, isNotNull);
        final codec = await ui.instantiateImageCodec(bytes!);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, lessThanOrEqualTo(512));
        expect(frame.image.height, lessThanOrEqualTo(512));
        frame.image.dispose();
        codec.dispose();
        expect(await store.load('/imagem-inexistente.png'), isNull);
        await expectLater(
            ArtworkStore.normalize(Uint8List(5 * 1024 * 1024 + 1)),
            throwsFormatException);
        await expectLater(ArtworkStore.normalize(Uint8List.fromList([1, 2, 3])),
            throwsA(anything));
      } finally {
        await temp.delete(recursive: true);
      }
    });
  });
}
