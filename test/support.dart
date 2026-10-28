import 'package:definitive_downloader/features/library/domain/models.dart';

Track testTrack(
        {String title = 'Entre linhas',
        String artist = 'Laboratório D.d',
        int? duration = 180000,
        String mediaUrl = '',
        String coverUrl = '',
        SourceKind kind = SourceKind.none}) =>
    Track(
        id: 1,
        collectionId: 1,
        position: 1,
        title: title,
        artist: artist,
        album: 'Ensaios',
        durationMs: duration,
        isrc: '',
        coverUrl: coverUrl,
        sourceUrl: '',
        mediaUrl: mediaUrl,
        sourceKind: kind,
        status: TrackStatus.ready,
        selected: true,
        localPath: '',
        error: '',
        resolvedTitle: '',
        resolvedArtist: '');

Candidate candidate(
        {String title = 'Entre linhas',
        String artist = 'Laboratório D.d',
        int duration = 180000}) =>
    Candidate(
        title: title,
        artist: artist,
        album: 'Ensaios',
        durationMs: duration,
        pageUrl: 'https://example.com/track',
        previewUrl: '',
        coverUrl: '');
