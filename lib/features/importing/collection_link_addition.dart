import 'dart:io';
import 'package:path/path.dart' as p;
import '../downloads/download_cancellation.dart';
import '../downloads/playlist_exporter.dart';
import '../library/data/library_repository.dart';
import '../library/domain/models.dart';
import 'collection_duplicates.dart';
import 'music_link.dart';
import 'music_link_repository.dart';
import 'replacement_media_files.dart';

class CollectionLinkAddition {
  const CollectionLinkAddition(this.repository);
  final LibraryRepository repository;
  Future<String> add(Collection owner, List<ResolvedMusicLink> entries,
      {ChooseDuplicate? choose,
      Future<ResolvedMusicLink> Function(ResolvedMusicLink)? prepare,
      required DownloadCancellation cancellation,
      required void Function() holdQueue,
      required String? Function() run,
      bool enqueue = true,
      required void Function(String) progress,
      Future<void> Function(List<Track>)? beforeRemoval}) async {
    final existing = await repository.database.run((db) => db
        .select(
            'SELECT * FROM tracks WHERE collection_id=? ORDER BY position LIMIT 10001',
            [owner.id])
        .map(LibraryRepository.readTrack)
        .toList());
    if (existing.length > 10000) {
      throw const FormatException('Limite de leitura da coleção excedido.');
    }
    progress('Verificando músicas já presentes na playlist.');
    final plan = await const CollectionDuplicates().review(existing, entries,
        choose: choose, cancellation: cancellation, onConflict: holdQueue);
    cancellation.check();
    if (plan.add.isEmpty) {
      return 'Nenhuma faixa adicionada. Versões existentes mantidas.';
    }
    final selected = <ResolvedMusicLink>[];
    for (var i = 0; i < plan.add.length; i++) {
      cancellation.check();
      progress('Conferindo faixas selecionadas: ${i + 1}/${plan.add.length}');
      selected.add(prepare == null ? plan.add[i] : await prepare(plan.add[i]));
    }
    final clock = Stopwatch()..start();
    List<Track> removed = [];
    while (true) {
      cancellation.check();
      removed = [];
      for (final old in plan.remove) {
        final fresh = await repository.trackById(old.id);
        if (fresh == null ||
            fresh.collectionId != owner.id ||
            fresh.title != old.title ||
            fresh.artist != old.artist ||
            fresh.position != old.position) {
          throw const FormatException(
              'A playlist mudou durante a revisão. Adicione os links novamente.');
        }
        removed.add(fresh);
      }
      if (!removed.any((t) => t.status == TrackStatus.downloading)) break;
      progress('Aguardando a transferência atual para substituir a versão.');
      if (clock.elapsed > const Duration(minutes: 5)) {
        throw const FormatException(
            'A transferência ainda está em andamento. Retome ou pare a fila e adicione os links novamente.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (removed.isNotEmpty) await beforeRemoval?.call(removed);
    cancellation.check();
    final files = ReplacementMediaFiles(repository);
    final operation = await files.stage(owner, removed, cancellation);
    var committed = false;
    String? warning;
    try {
      cancellation.check();
      await MusicLinkRepository(repository.database).append(owner.id, selected,
          run: run(), enqueue: enqueue, replaced: removed);
      committed = true;
    } finally {
      warning =
          await files.recover(operation: operation, updatePlaylist: false);
      if (!committed && warning != null) throw FormatException(warning);
    }
    for (final directory in removed
        .where((t) => t.localPath.isNotEmpty)
        .map((t) => p.dirname(t.localPath))
        .toSet()) {
      try {
        if (await Directory(directory).exists()) {
          await PlaylistExporter(repository).export(owner.id, directory);
        }
      } catch (_) {
        warning = 'Não foi possível atualizar a M3U8.';
      }
    }
    return '${plan.add.length} faixa(s) adicionada(s). ${plan.remove.length} substituída(s). ${plan.skipped} recebida(s) descartada(s).${warning == null ? '' : ' $warning'}';
  }
}
