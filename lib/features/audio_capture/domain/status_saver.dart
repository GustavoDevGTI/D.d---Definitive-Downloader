/// A WhatsApp status copied by the app (Status Saver, Android only).
class WhatsAppStatus {
  const WhatsAppStatus(
      {required this.path,
      required this.modified,
      required this.bytes,
      required this.isVideo});
  final String path;
  final DateTime modified;
  final int bytes;
  final bool isVideo;
}

const statusVideoExtensions = {'.mp4', '.3gp', '.mkv', '.webm'};
const statusAudioExtensions = {'.opus', '.ogg', '.m4a', '.aac', '.mp3'};

String _two(int value) => value.toString().padLeft(2, '0');

/// "Status 27/11 14:30"; repeated minutes get a counter.
List<String> statusTitles(List<WhatsAppStatus> statuses) {
  final seen = <String, int>{};
  return [
    for (final status in statuses)
      () {
        final m = status.modified;
        final base =
            'Status ${_two(m.day)}/${_two(m.month)} ${_two(m.hour)}:${_two(m.minute)}';
        final count = seen[base] = (seen[base] ?? 0) + 1;
        return count == 1 ? base : '$base ($count)';
      }()
  ];
}

/// Name of the playlist (and its folder) created from statuses saved at [at].
String statusPlaylistName(DateTime at) =>
    'Status do WhatsApp ${_two(at.day)}-${_two(at.month)}-${at.year} '
    '${_two(at.hour)}h${_two(at.minute)}';

String formatStatusBytes(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB'
    : '${(bytes / 1024).ceil()} KB';
