import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Real HTTP is limited to the local server started by each test.
  HttpOverrides.global = null;
  test('recebe MP3 por HTTP e grava capa embutida sem conta', () async {
    final directory = await Directory.systemTemp.createTemp('dd-download-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final file = File(request.uri.path == '/cover.png'
          ? 'assets/demo/cover.png'
          : 'assets/demo/tone.mp3');
      request.response.contentLength = await file.length();
      await request.response.addStream(file.openRead());
      await request.response.close();
    });
    try {
      final base = 'http://127.0.0.1:${server.port}';
      final track = testTrack(
          mediaUrl: '$base/tone.mp3',
          coverUrl: '$base/cover.png',
          kind: SourceKind.directMp3);
      final path = await DownloadService(const BoundedHttp(), rootBundle)
          .save(track, directory.path, DownloadCancellation(), (_) {});
      final bytes = await File(path).readAsBytes();
      expect(String.fromCharCodes(bytes.take(3)), 'ID3');
      expect(String.fromCharCodes(bytes).contains('APIC'), true);
      final cover = await File('assets/demo/cover.png').readAsBytes();
      final data = String.fromCharCodes(bytes);
      expect(data.contains(String.fromCharCodes(cover)), true);
      expect(await File('$path.part').exists(), false);
    } finally {
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
  test('não publica HTML disfarçado de MP3', () async {
    final directory = await Directory.systemTemp.createTemp('dd-download-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.write('<html>login required</html>');
      await request.response.close();
    });
    try {
      final track = testTrack(
          mediaUrl: 'http://127.0.0.1:${server.port}/fake.mp3',
          kind: SourceKind.directMp3);
      await expectLater(
          DownloadService(const BoundedHttp(), rootBundle)
              .save(track, directory.path, DownloadCancellation(), (_) {}),
          throwsFormatException);
      expect(
          directory
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.mp3')),
          isEmpty);
    } finally {
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
  test('nomes de saída não escapam da pasta ou usam dispositivos reservados',
      () {
    expect(safeSegment('../../CON:*'), '.. .. CON');
    expect(safeSegment('CON'), '_CON');
    expect(safeSegment(''), 'Sem nome');
  });
}
