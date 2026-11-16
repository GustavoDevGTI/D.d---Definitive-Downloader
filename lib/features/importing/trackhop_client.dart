import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../core/network/platform_trust.dart';
import '../downloads/download_cancellation.dart';
import '../library/domain/models.dart';
import 'spotify_importer.dart';

class TrackhopClient {
  TrackhopClient(this.origin, this._token);

  static const desktopAddress = 'http://127.0.0.1:8642';
  final Uri origin;
  final String _token;
  String? _service;

  static Uri validateAddress(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !(uri.scheme == 'https' ||
            uri.scheme == 'http' && uri.host == '127.0.0.1')) {
      throw const FormatException(
          'Use um endereço HTTPS do Trackhop ou o endereço local do desktop.');
    }
    return uri.replace(path: '');
  }

  Future<void> check() async {
    final services = await _read(['services']);
    for (final row in services.whereType<Map>()) {
      final id = row['id'];
      if (row['serviceId'] == 'spotify_bridge' &&
          row['connected'] == true &&
          id is String &&
          RegExp(r'^spotify_bridge(?:@[0-9]+)?$').hasMatch(id)) {
        _service = id;
        return;
      }
    }
    throw const FormatException(
        'Conecte Spotify (web) no Trackhop e teste novamente.');
  }

  Future<ImportedCollection> playlist(String url,
      {bool Function()? cancelled, void Function(int, int)? onProgress}) async {
    final id = SpotifyImporter.idFromLink(url);
    final service = await _connectedService();
    final path = ['services', service, 'playlists'];
    final lists = await _read(path, cancelled: cancelled);
    final info =
        lists.whereType<Map>().where((row) => row['id'] == id).firstOrNull;
    final name = _text(info?['name'], fallback: 'Playlist Spotify');
    final expected = info?['tracks'];
    if (expected is int && expected > 10000) {
      throw const FormatException(
          'O D.d aceita até 10.000 faixas por playlist.');
    }
    final rows = await _read([...path, id, 'tracks'], cancelled: cancelled);
    if (rows.isEmpty ||
        rows.length > 10000 ||
        expected is int && expected > 0 && rows.length != expected) {
      throw const FormatException(
          'O Trackhop retornou uma playlist vazia, incompleta ou acima do limite.');
    }
    final tracks = rows.map(parseTrack).toList(growable: false);
    onProgress?.call(tracks.length, tracks.length);
    return ImportedCollection(
        name: name,
        source: 'Spotify · Trackhop',
        sourceUrl: 'https://open.spotify.com/playlist/$id',
        tracks: Stream.fromIterable(tracks));
  }

  Future<TrackDraft> track(String id, String url) async {
    final service = await _connectedService();
    final rows =
        await _read(['services', service, 'search'], query: {'q': url});
    final row =
        rows.whereType<Map>().where((value) => value['id'] == id).firstOrNull;
    if (row == null) {
      throw const FormatException(
          'O Trackhop não encontrou esta faixa pelo link.');
    }
    return parseTrack(row);
  }

  Future<String> _connectedService() async {
    if (_service == null) await check();
    return _service!;
  }

  static String _text(Object? value, {String fallback = ''}) =>
      value is String && value.trim().isNotEmpty && value.length <= 400
          ? value.trim()
          : fallback;

  static TrackDraft parseTrack(Object? value) {
    if (value is! Map ||
        _text(value['title']).isEmpty ||
        value['artists'] is! List) {
      throw const FormatException('O Trackhop retornou metadados incompletos.');
    }
    final id = value['id'];
    final duration = value['durationMs'];
    final explicit = value['explicit'];
    final cover = _text(value['coverUrl']);
    return TrackDraft(
        title: _text(value['title']),
        artist: (value['artists'] as List)
            .take(32)
            .map((artist) => _text(artist))
            .where((artist) => artist.isNotEmpty)
            .join(', '),
        album: _text(value['album']),
        durationMs: duration is int && duration > 0 ? duration : null,
        isrc: _text(value['isrc']),
        explicit: explicit is bool ? explicit : null,
        coverUrl:
            RegExp(r'^https://i\.scdn\.co/image/[A-Za-z0-9]+$').hasMatch(cover)
                ? cover
                : '',
        sourceUrl: id is String && RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(id)
            ? 'https://open.spotify.com/track/$id'
            : '');
  }

  Future<List<dynamic>> _read(List<String> path,
      {Map<String, String>? query, bool Function()? cancelled}) async {
    if (cancelled?.call() == true) throw const DownloadCancelled();
    final uri = validateAddress(origin.toString())
        .replace(pathSegments: ['api', 'v1', ...path], queryParameters: query);
    final client = HttpClient(context: await platformSecurityContext())
      ..connectionTimeout = const Duration(seconds: 6)
      ..findProxy = (_) => 'DIRECT';
    final timeout =
        Timer(const Duration(seconds: 90), () => client.close(force: true));
    final cancelTimer = cancelled == null
        ? null
        : Timer.periodic(const Duration(milliseconds: 200), (timer) {
            if (cancelled()) client.close(force: true);
          });
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const FormatException(
            'O Trackhop recusou o token. Gere um token em Ferramentas → API.');
      }
      if (response.statusCode == 409 || response.statusCode == 502) {
        throw const FormatException(
            'O Trackhop não conseguiu ler o Spotify. Confira a sessão e o acesso à playlist no Trackhop.');
      }
      if (response.statusCode != 200) {
        throw FormatException(
            'O Trackhop respondeu HTTP ${response.statusCode}.');
      }
      const limit = 12 * 1024 * 1024;
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        if (bytes.length + chunk.length > limit) {
          throw const FormatException(
              'A resposta do Trackhop excedeu o limite de leitura.');
        }
        bytes.add(chunk);
      }
      final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
      if (decoded is List) return decoded;
      throw const FormatException('A resposta do Trackhop não é uma lista.');
    } on IOException {
      if (cancelled?.call() == true) throw const DownloadCancelled();
      throw const FormatException(
          'Não foi possível acessar o Trackhop. Confira se está aberto e se o endereço está correto.');
    } finally {
      cancelTimer?.cancel();
      timeout.cancel();
      client.close(force: true);
    }
  }
}
