import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/platform/android_documents.dart';
import 'package:definitive_downloader/core/platform/media_publication.dart';

/// Exercise native cleanup with only this scenario's private fixture files.
Future<void> checkPrivatePublicationGuards(
    String destination, int collection, Directory work) async {
  final documents = AndroidDocuments();
  final directory = '$destination/Guard';
  final key = '0' * 64;
  const track = 987654321;
  Future<String> prepare() =>
      documents.transferDirectory(directory, track, collection, key);
  final original = File('${work.path}/original.txt');
  await original.writeAsString('preserve original');
  final first = await prepare();
  final partial = File('$first/audio.part');
  await partial.writeAsString('partial transfer');
  final link = Link('$first/external');
  await link.create(original.path);
  await expectLater(prepare(), throwsA(isA<MediaPublicationFailure>()));
  expect(await original.readAsString(), 'preserve original');
  expect(await partial.readAsString(), 'partial transfer');
  await link.delete();
  final complete = File('$first/ready.mp3');
  await complete.writeAsString('complete audio must be reused, never retired');
  await expectLater(prepare(), throwsA(isA<MediaPublicationFailure>()));
  expect(await complete.exists(), isTrue);
  await complete.delete();
  final second = await prepare();
  expect(second, isNot(first));
  expect(await Directory(first).exists(), isFalse);
  expect(await Directory(second).exists(), isTrue);
  expect(await original.readAsString(), 'preserve original');
}
