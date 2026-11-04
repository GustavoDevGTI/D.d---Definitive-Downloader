import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/features/library/data/artwork_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
