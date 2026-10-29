// Explicit vector export, outside the default test suite. No image is generated
// by a model: these PNGs render the same traced paths used by Flutter.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/brand.dart';

void main() {
  test('exporta marca vetorial para resoluções de ícone', () async {
    final output = Platform.environment['DD_BRAND_OUTPUT'];
    if (output == null) throw StateError('Informe DD_BRAND_OUTPUT.');
    await Directory(output).create(recursive: true);
    for (final tone in BrandTone.values) {
      for (final edge in [16, 20, 24, 32, 40, 48, 64, 128, 256, 512, 1024]) {
        final recorder = ui.PictureRecorder();
        BrandMarkPainter(tone)
            .paint(ui.Canvas(recorder), ui.Size.square(edge.toDouble()));
        final picture = recorder.endRecording();
        final image = await picture.toImage(edge, edge);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$output/dd-mark-${tone.name}-$edge.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
          picture.dispose();
        }
      }
    }
  });
}
