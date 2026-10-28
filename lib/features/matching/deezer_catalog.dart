import 'dart:convert';
import '../../core/network/bounded_http.dart';
import '../library/domain/models.dart';

class DeezerCatalog {
  const DeezerCatalog(this.http);
  final BoundedHttp http;
  Future<List<Candidate>> search(String query) async {
    if (query.trim().length < 2 || query.length > 300) {
      throw const FormatException('Digite entre 2 e 300 caracteres.');
    }
    final body = await http.text(Uri.https(
        'api.deezer.com', '/search', {'q': query.trim(), 'limit': '8'}));
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (data.containsKey('error')) {
      throw const FormatException(
          'O catálogo está temporariamente indisponível.');
    }
    final rows = data['data'];
    if (rows is! List) return [];
    return rows
        .whereType<Map<String, dynamic>>()
        .take(8)
        .map((row) => Candidate(
            title: (row['title'] ?? '').toString(),
            artist: (row['artist']?['name'] ?? '').toString(),
            album: (row['album']?['title'] ?? '').toString(),
            durationMs: ((row['duration'] as num?)?.toInt() ?? 0) * 1000,
            pageUrl: (row['link'] ?? '').toString(),
            previewUrl: (row['preview'] ?? '').toString(),
            coverUrl: (row['album']?['cover_medium'] ?? '').toString(),
            isrc: (row['isrc'] ?? '').toString()))
        .toList();
  }
}
