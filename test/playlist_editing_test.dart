import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/data/playlist_editor.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/importing/music_link.dart';
import 'package:definitive_downloader/features/importing/music_link_repository.dart';
import 'package:definitive_downloader/features/workspace/data/workspace_repository.dart';

Candidate clip() => const Candidate(
    title: 'Canção (Official Video)',
    artist: 'Pessoa',
    album: '',
    durationMs: 200000,
    pageUrl: 'https://www.youtube.com/watch?v=abcdefghijk',
    previewUrl: '',
    coverUrl: '',
    kind: SourceKind.youtube,
    recordingType: 'MUSIC_VIDEO_TYPE_OMV');

void main() {
  late Directory temp;
  late LibraryRepository library;
  late PlaylistEditor editor;
  late WorkspaceRepository queue;
  late int owner;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dd-editing-');
    library = LibraryRepository(AppDatabase('${temp.path}/library.db'));
    await library.database.initialize();
    editor = PlaylistEditor(library.database);
    queue = WorkspaceRepository(library.database);
    owner = await library.importCollection(ImportedCollection(
        name: 'Coleção',
        source: 'Fixture',
        sourceUrl: '',
        tracks: Stream.fromIterable(List.generate(
            85,
            (i) => const TrackDraft(
                title: 'Canção',
                artist: 'Pessoa',
                durationMs: 180000,
                mediaUrl: 'https://example.org/audio.mp3',
                sourceKind: SourceKind.directMp3)))));
  });
  tearDown(() => temp.delete(recursive: true));
  test(
      'move através de páginas em ambos os sentidos preservando repetições e identidade',
      () async {
    final before = (await library.page(owner, limit: 100)).items;
    await editor.edit(before.first.id, name: 'Meu nome', position: 85);
    var after = (await library.page(owner, limit: 100)).items;
    expect(after.map((t) => t.id),
        [...before.skip(1).map((t) => t.id), before.first.id]);
    expect(after.map((t) => t.position), List.generate(85, (i) => i + 1));
    expect(after.last.title, 'Canção');
    expect(after.last.displayTitle, 'Meu nome');
    expect(after.last.outputTitle, 'Meu nome');
    expect((await library.page(owner, query: 'Meu nome')).total, 1);
    await editor.edit(before.first.id, name: 'Meu nome', position: 1);
    after = (await library.page(owner, limit: 100)).items;
    expect(after.map((t) => t.id), before.map((t) => t.id));
    await expectLater(editor.edit(before[1].id, name: 'X', position: 86),
        throwsFormatException);
    expect((await library.page(owner, limit: 100)).items.map((t) => t.id),
        before.map((t) => t.id));
  });
  test(
      'primeira reivindicação bloqueia toda coleção, inclusive extras e após reinício',
      () async {
    final rows = (await library.page(owner)).items;
    await queue.claimNext(run: 'attempt', ids: [rows.first.id]);
    expect((await library.collectionById(owner))!.editingLocked, isTrue);
    await expectLater(editor.edit(rows[1].id, name: 'Novo', position: 3),
        throwsFormatException);
    await library.setStatus(rows.first.id, TrackStatus.failed);
    await library.database.initialize();
    await expectLater(editor.edit(rows.first.id, name: 'Novo', position: 1),
        throwsFormatException);
    final extra = ResolvedMusicLink(
        link: MusicLink.parse('https://example.org/extra.mp3'),
        pinned: true,
        ready: true,
        draft: const TrackDraft(
            title: 'Extra',
            artist: '',
            sourceKind: SourceKind.directMp3,
            mediaUrl: 'https://example.org/extra.mp3'));
    final ids =
        await MusicLinkRepository(library.database).append(owner, [extra]);
    expect((await library.trackById(ids.single))!.position, 86);
    await expectLater(editor.edit(ids.single, name: 'Outro', position: 2),
        throwsFormatException);
  });
  test(
      'alteração de ID da plataforma mantém PK e posição; falha reverte o movimento',
      () async {
    final track = (await library.page(owner)).items.first;
    final replacement = ResolvedMusicLink(
        link: MusicLink.parse('https://www.youtube.com/watch?v=abcdefghijk'),
        draft: const TrackDraft(title: 'Outra fonte', artist: 'Pessoa'),
        source: clip(),
        pinned: true,
        ready: true,
        alternatives: [clip()]);
    await editor.edit(track.id,
        name: 'Nome escolhido', position: 2, replacement: replacement);
    final changed = (await library.trackById(track.id))!;
    expect(changed.id, track.id);
    expect(changed.position, 2);
    expect(changed.sourceUrl, replacement.link.url);
    expect(changed.manualUrl, replacement.link.url);
    expect(changed.sourceAuthorization, SourceAuthorization.manualLink);
    expect(changed.canDownload, isTrue);
    final invalid = ResolvedMusicLink(
        link: replacement.link,
        draft: replacement.draft,
        source: clip(),
        pinned: false);
    await expectLater(
        editor.edit(track.id,
            name: 'Errado', position: 5, replacement: invalid),
        throwsFormatException);
    expect((await library.trackById(track.id))!.position, 2);
  });
  test(
      'videoclipe automático exige aprovação da ocorrência e preserva duração original',
      () async {
    final track = (await library.page(owner)).items.first;
    await library.saveCandidates(track.id, [clip()]);
    await expectLater(
        library.chooseMusicSource(track, clip()), throwsFormatException);
    await library.chooseMusicSource(track, clip(), approveVideo: true);
    final chosen = (await library.trackById(track.id))!;
    expect(chosen.sourceAuthorization, SourceAuthorization.approvedVideo);
    expect(chosen.durationMs, 180000);
    expect(chosen.outputDurationMs, 200000);
    expect(chosen.canDownload, isTrue);
    final other = (await library.page(owner)).items[1];
    await expectLater(
        library.chooseMusicSource(other, clip(), approveVideo: true),
        throwsFormatException);
    await library.database.initialize();
    expect((await library.trackById(track.id))!.sourceAuthorization,
        SourceAuthorization.approvedVideo);
  });
  test(
      'migração v8 bloqueia coleção com histórico e preserva coleção ainda não iniciada',
      () async {
    final track = (await library.page(owner)).items.first;
    await library.setStatus(track.id, TrackStatus.completed,
        localPath: '${temp.path}/fixture.mp3');
    final untouched = await library.importCollection(ImportedCollection(
        name: 'Nova',
        source: 'Fixture',
        sourceUrl: '',
        tracks:
            Stream.value(const TrackDraft(title: 'Nova', artist: 'Pessoa'))));
    await library.database.run((db) {
      db.execute('ALTER TABLE collections DROP COLUMN editing_locked');
      for (final c in [
        'custom_title',
        'recording_type',
        'source_authorization'
      ]) {
        db.execute('ALTER TABLE tracks DROP COLUMN $c');
      }
      db.execute('PRAGMA user_version=8');
    });
    await library.database.initialize();
    expect((await library.collectionById(owner))!.editingLocked, isTrue);
    expect((await library.collectionById(untouched))!.editingLocked, isFalse);
    expect((await library.trackById(track.id))!.localPath,
        '${temp.path}/fixture.mp3');
  });
}
