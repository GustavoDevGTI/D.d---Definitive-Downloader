import '../library/domain/models.dart';

ImportedCollection demoCollection() => ImportedCollection(
    name: 'Entre linhas',
    source: 'Exemplo local',
    sourceUrl: '',
    tracks: Stream.fromIterable(List.generate(
        6,
        (index) => TrackDraft(
            title: const [
              'Abertura',
              'Entre linhas',
              'Ponto de encontro',
              'Margem',
              'Intervalo',
              'Entre linhas'
            ][index],
            artist: 'Laboratório D.d',
            album: 'Ensaios de uma coleção',
            durationMs: 4000,
            coverUrl: 'asset:assets/demo/cover.png',
            mediaUrl: 'asset:assets/demo/tone.mp3',
            sourceKind: SourceKind.localExample))));
