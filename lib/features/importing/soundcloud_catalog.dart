import 'dart:convert';
import 'dart:isolate';
import 'package:html/parser.dart' as html;
import '../library/domain/models.dart';
import '../downloads/download_cancellation.dart';
import 'soundcloud_link.dart';
import 'soundcloud_transport.dart';

/// Public web metadata adapter shared by desktop/mobile; never obtains audio.
class SoundCloudCatalog {
  SoundCloudCatalog({this.transport = const PublicSoundCloudTransport()});
  final SoundCloudTransport transport;
  String? _webClientId;
  DateTime? _clientReadAt;

  Future<({Map<String, dynamic> row, String html, SoundCloudLink link})> _read(
      String input) async {
    final link = SoundCloudLink.parse(input);
    final response =
        await transport.get(Uri.parse(link.url), maximumBytes: 2 * 1024 * 1024);
    final canonical = SoundCloudLink.parse(response.url.toString());
    final row = await _parsePage(response.text, canonical);
    return (row: row, html: response.text, link: canonical);
  }

  static Future<Map<String, dynamic>> _parsePage(
          String text, SoundCloudLink link) =>
      Isolate.run(() => _hydration(text, link));
  static Future<dynamic> _json(String text) =>
      Isolate.run(() => jsonDecode(text));
  static Future<List<String>> _assets(String page) => Isolate.run(() => html
      .parse(page)
      .querySelectorAll('script[src]')
      .map((e) => e.attributes['src']!)
      .where((s) =>
          s.startsWith('https://a-v2.sndcdn.com/assets/') && s.endsWith('.js'))
      .toList());
  static Future<String?> _scanAsset(String text) => Isolate.run(() =>
      RegExp('client_id\\s*:\\s*["\x27]([A-Za-z0-9]{32})["\x27]')
          .firstMatch(text)
          ?.group(1));
  static Future<List<TrackDraft>> _drafts(List<Map<String, dynamic>> ordered,
          Map<String, Map<String, dynamic>> resolved) =>
      Isolate.run(() => ordered.map((row) {
            final id = _id(row['id']);
            final full = row['title'] == null ? resolved[id] : row;
            return full == null
                ? TrackDraft(
                    title: 'Faixa indisponível (SoundCloud $id)',
                    artist: '',
                    sourceUrl: 'https://api.soundcloud.com/tracks/$id')
                : _draft(full);
          }).toList());

  static Map<String, dynamic> _hydration(
      String page, SoundCloudLink canonical) {
    final document = html.parse(page);
    for (final script in document.querySelectorAll('script')) {
      final match =
          RegExp(r'window\.__sc_hydration\s*=\s*').firstMatch(script.text);
      if (match == null) continue;
      final raw = script.text
          .substring(match.end)
          .trim()
          .replaceFirst(RegExp(r';\s*$'), '');
      final payload = jsonDecode(raw);
      if (payload is! List || payload.length > 100) break;
      for (final value in payload.whereType<Map>()) {
        if (value['hydratable'] != 'sound' &&
            value['hydratable'] != 'playlist') {
          continue;
        }
        if (value['data'] is! Map) continue;
        final row = Map<String, dynamic>.from(value['data'] as Map);
        final isList = value['hydratable'] == 'playlist';
        if (isList != (canonical.resource == SoundCloudResource.playlist)) {
          continue;
        }
        if (row['public'] == false || row['sharing'] == 'private') {
          throw const FormatException(
              'Esta etapa aceita somente SoundCloud público.');
        }
        final resource = SoundCloudLink.parse(_text(row['permalink_url']));
        if (resource.url != canonical.url) {
          throw const FormatException(
              'A resposta não corresponde ao link SoundCloud.');
        }
        return row;
      }
    }
    throw const FormatException(
        'Não foi possível ler a faixa ou playlist pública do SoundCloud.');
  }

  Future<TrackDraft> track(String input) async {
    final data = await _read(input);
    if (data.link.resource != SoundCloudResource.track) {
      throw const FormatException(
          'Adicione faixas individuais aqui; use Importar playlist para uma lista SoundCloud.');
    }
    return _draft(data.row);
  }

  Future<ImportedCollection> open(String input,
      {void Function(int, int)? onProgress, bool Function()? cancelled}) async {
    void check() {
      if (cancelled?.call() == true) throw const DownloadCancelled();
    }

    check();
    final data = await _read(input);
    check();
    if (data.link.resource == SoundCloudResource.track) {
      final draft = _draft(data.row);
      return ImportedCollection(
          name: draft.title,
          source: 'SoundCloud · público',
          sourceUrl: data.link.url,
          tracks: Stream.value(draft));
    }
    final rows = data.row['tracks'];
    final total = data.row['track_count'];
    if (rows is! List ||
        total is! int ||
        total < 1 ||
        total > 10000 ||
        rows.length != total) {
      throw const FormatException(
          'A playlist SoundCloud está incompleta ou excede 10.000 faixas.');
    }
    final ordered = rows
        .map((r) => r is Map
            ? Map<String, dynamic>.from(r)
            : throw const FormatException('Faixa SoundCloud inválida.'))
        .toList();
    final pending = ordered
        .where((r) => r['title'] == null)
        .map((r) => _id(r['id']))
        .toSet()
        .toList();
    final resolved = <String, Map<String, dynamic>>{};
    if (pending.isNotEmpty) {
      final client = await _clientId(data.html);
      for (var start = 0; start < pending.length; start += 25) {
        check();
        final ids = pending.skip(start).take(25).toList();
        final response = await transport.get(
            Uri.https('api-v2.soundcloud.com', '/tracks',
                {'ids': ids.join(','), 'client_id': client}),
            maximumBytes: 2 * 1024 * 1024);
        check();
        final payload = await _json(response.text);
        if (payload is! List || payload.length > ids.length) {
          throw const FormatException(
              'Resposta de faixas SoundCloud inválida.');
        }
        for (final item in payload.whereType<Map>()) {
          final id = _id(item['id']);
          if (!ids.contains(id) || resolved.containsKey(id)) {
            throw const FormatException(
                'IDs SoundCloud não correspondem à playlist.');
          }
          resolved[id] = Map<String, dynamic>.from(item);
        }
        onProgress?.call(
            (start + ids.length).clamp(0, pending.length), pending.length);
      }
    }
    check();
    final drafts = await _drafts(ordered, resolved);
    check();
    return ImportedCollection(
        name: _text(data.row['title']),
        source: 'SoundCloud · público',
        sourceUrl: data.link.url,
        tracks: Stream.fromIterable(drafts));
  }

  Future<String> _clientId(String page) async {
    if (_webClientId != null &&
        _clientReadAt != null &&
        DateTime.now().difference(_clientReadAt!).inMinutes < 60) {
      return _webClientId!;
    }
    final scripts = await _assets(page);
    for (final source in scripts.reversed.take(3)) {
      final script =
          await transport.get(Uri.parse(source), maximumBytes: 4 * 1024 * 1024);
      final found = await _scanAsset(script.text);
      if (found != null) {
        _clientReadAt = DateTime.now();
        return _webClientId = found;
      }
    }
    throw const FormatException(
        'O leitor público do SoundCloud mudou. Tente novamente mais tarde.');
  }

  static TrackDraft _draft(Map<String, dynamic> row) {
    _id(row['id']);
    final reference = SoundCloudLink.parse(_text(row['permalink_url']));
    if (reference.resource != SoundCloudResource.track ||
        row['public'] == false ||
        row['sharing'] == 'private') {
      throw const FormatException('Faixa SoundCloud não é pública.');
    }
    final publisher = row['publisher_metadata'];
    final rawDuration = row['full_duration'] ?? row['duration'];
    final duration = rawDuration is num ? rawDuration.round() : null;
    final cover = row['artwork_url'];
    final image = cover is String &&
            cover.length <= 2048 &&
            Uri.tryParse(cover)?.scheme == 'https' &&
            Uri.tryParse(cover)?.userInfo.isEmpty == true
        ? cover
        : '';
    return TrackDraft(
        title: _text(row['title']),
        artist:
            publisher is Map ? _text(publisher['artist'], optional: true) : '',
        album: publisher is Map
            ? _text(publisher['release_title'], optional: true)
            : '',
        isrc: publisher is Map ? _text(publisher['isrc'], optional: true) : '',
        durationMs: duration != null && duration >= 1000 && duration <= 3600000
            ? duration
            : null,
        coverUrl: image,
        sourceUrl: reference.url);
  }

  static String _id(Object? value) {
    final id = '$value';
    if (!RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(id)) {
      throw const FormatException('ID SoundCloud inválido.');
    }
    return id;
  }

  static String _text(Object? value, {bool optional = false}) {
    if (value == null && optional) return '';
    if (value is! String ||
        value.length > 400 ||
        value.contains(RegExp(r'[\x00-\x1f]')) ||
        (!optional && value.trim().isEmpty)) {
      throw const FormatException('Metadados SoundCloud inválidos.');
    }
    return value.trim();
  }
}
