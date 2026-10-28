import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/library/domain/matching.dart';
import 'support.dart';

Candidate song({String type = 'MUSIC_VIDEO_TYPE_ATV', int duration = 180000}) =>
    Candidate(
        title: 'Entre linhas',
        artist: 'Meu artista',
        album: 'Album',
        durationMs: duration,
        pageUrl: 'https://music.youtube.com/watch?v=abcdefghijk',
        previewUrl: '',
        coverUrl: 'https://lh3.googleusercontent.com/cover',
        kind: SourceKind.youtubeMusic,
        recordingType: type);

void main() {
  test(
      'videoclipe e tipo ausente são bloqueados mesmo com ISRC/título compatíveis',
      () {
    for (final type in ['MUSIC_VIDEO_TYPE_OMV', 'MUSIC_VIDEO_TYPE_UGC', '']) {
      final candidate = song(type: type);
      expect(candidate.isFullRecording, false);
      expect(const TrackMatcher().assess(testTrack(), candidate).needsReview,
          true);
    }
  });
  test('uma duração de videoclipe não vira gravação certa por título igual',
      () {
    expect(
        const TrackMatcher()
            .assess(testTrack(duration: 180000), song(duration: 190000))
            .needsReview,
        true);
  });
  test('candidatos persistem por ocorrência sem alterar o Spotify original',
      () async {
    final folder = await Directory.systemTemp.createTemp('dd-music-db-');
    try {
      final repository =
          LibraryRepository(AppDatabase('${folder.path}/test.db'));
      await repository.database.initialize();
      final id = await repository.importCollection(ImportedCollection(
          name: 'Lista',
          source: 'Teste',
          sourceUrl: '',
          tracks: Stream.fromIterable([
            const TrackDraft(
                title: 'Entre linhas',
                artist: 'Meu artista',
                coverUrl: 'https://original/cover',
                isrc: 'TESTISRC'),
            const TrackDraft(
                title: 'Entre linhas',
                artist: 'Meu artista',
                coverUrl: 'https://original/cover',
                isrc: 'TESTISRC'),
          ])));
      final page = await repository.page(id);
      await repository.saveCandidates(page.items.first.id, [song()]);
      await repository.chooseMusicSource(page.items.first, song());
      final updated = await repository.page(id);
      expect(updated.items.map((t) => t.position), [1, 2]);
      expect(updated.items.first.coverUrl, 'https://original/cover');
      expect(updated.items.first.isrc, 'TESTISRC');
      expect(
          updated.items.first.resolvedCoverUrl, contains('googleusercontent'));
      await repository.recordMusicAttempt(
          page.items.first.id, SourceKind.deezerFull,
          succeeded: false, message: 'A fonte recusou a faixa.');
      await repository.recordMusicAttempt(
          page.items.first.id, SourceKind.youtubeMusic,
          succeeded: true);
      await repository.recordMusicAttempt(
          page.items.first.id, SourceKind.youtubeMusic,
          succeeded: true);
      final attempts = await repository.database.run((db) => db
          .select(
              'SELECT provider,succeeded,message FROM music_source_attempts WHERE track_id=? ORDER BY provider',
              [page.items.first.id])
          .map((r) => Map<String, Object?>.from(r))
          .toList());
      expect(attempts.length, 2);
      expect(attempts.first['succeeded'], 0);
      expect(attempts.first['message'], 'A fonte recusou a faixa.');
      expect(attempts.last['succeeded'], 1);
      expect(updated.items.last.sourceKind, SourceKind.none);
      expect(await repository.musicCandidates(updated.items.last.id), isEmpty);
      await expectLater(
          repository.chooseMusicSource(
              updated.items.last, song(type: 'MUSIC_VIDEO_TYPE_OMV')),
          throwsFormatException);
    } finally {
      await folder.delete(recursive: true);
    }
  });
}
