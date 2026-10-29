// Research runner. Reuses the tested PKCE listener, never the saved D.d session.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:definitive_downloader/features/connections/data/spotify_transport.dart';
import 'package:definitive_downloader/features/connections/data/windows_spotify_authorization.dart';
import 'package:definitive_downloader/features/connections/domain/spotify_auth.dart';

Future<void> runEngine(Map<String, dynamic> engine, String token, String track,
    Directory output) async {
  final name = engine['name'] as String;
  final command = engine['command'] as String;
  final prefix = (engine['arguments'] as List).cast<String>();
  final destination = '${output.path}/$name.${engine['extension']}';
  final process = await Process.start(command, [...prefix, track, destination]);
  final lines = <String>[];
  final diagnosticCounts = <String, int>{};
  final stdoutDone = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
    // Both child harnesses emit only bounded stage statuses; do not echo other logs.
    if (line.length <= 1024 &&
        (line.startsWith('{"stage":') ||
            RegExp(r'^(SESSION|METADATA|AUDIO)_[A-Z0-9_]+(?::[A-Za-z0-9_]+)?$')
                .hasMatch(line))) {
      if (line.startsWith('{"stage":"native_log"')) {
        if (diagnosticCounts.containsKey(line)) {
          diagnosticCounts[line] = diagnosticCounts[line]! + 1;
          return;
        }
        // Keep repeated decoder warnings bounded without hiding final statuses.
        if (diagnosticCounts.length >= 64) {
          return;
        }
        diagnosticCounts[line] = 1;
      }
      lines.add(line);
      stdout.writeln('$name: $line');
    }
  }).asFuture<void>();
  // Drain stderr without exporting potentially sensitive upstream diagnostics.
  final stderrDone = process.stderr.drain<void>();
  process.stdin.writeln(token);
  await process.stdin.close();
  var timedOut = false;
  final code =
      await process.exitCode.timeout(const Duration(minutes: 7), onTimeout: () {
    timedOut = true;
    process.kill();
    return -1;
  });
  await Future.wait([stdoutDone, stderrDone])
      .timeout(const Duration(seconds: 10));
  final file = File(destination);
  final result = {
    'engine': name,
    'exitCode': code,
    'timeout': timedOut,
    'events': lines,
    'diagnosticCounts': diagnosticCounts,
    'bytes': await file.exists() ? await file.length() : 0
  };
  await File('${output.path}/$name-result.json')
      .writeAsString(jsonEncode(result));
  stdout.writeln(jsonEncode(result));
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('Expected probe configuration path.');
  }
  final file = File(args.single);
  if (await file.length() > 32768) {
    throw ArgumentError('Configuration too large.');
  }
  final config = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final output = Directory(config['output'] as String);
  await output.create(recursive: true);
  final clientId = config['authClientId'] as String? ?? SpotifyConfig.clientId;
  final redirect = config['redirectUri'] == null
      ? SpotifyConfig.windowsRedirect
      : Uri.parse(config['redirectUri'] as String);
  final authorization = WindowsSpotifyAuthorization(
      redirectUri: redirect,
      openBrowser: (uri) async {
        // Additional playback scope belongs only to this explicit research consent.
        final playbackUri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'client_id': clientId,
          'scope':
              'streaming user-read-private playlist-read-private playlist-read-collaborative'
        });
        // Authorization URL contains only public PKCE parameters, never a token
        // or the verifier. Keep this fallback out of persisted evidence logs.
        stdout.writeln('AUTHORIZATION_URL: $playbackUri');
        final launch = await Process.run('powershell.exe', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'Start-Process -FilePath $env:DD_SPOTIFY_AUTH_URL -ErrorAction Stop'
        ], environment: {
          'DD_SPOTIFY_AUTH_URL': playbackUri.toString()
        });
        stdout.writeln('BROWSER_LAUNCH_EXIT: ${launch.exitCode}');
      },
      timeout: const Duration(minutes: 8));
  try {
    stdout.writeln(
        'AUTH_WAITING: autorize o ensaio na pagina oficial do Spotify.');
    final request =
        SpotifyAuthorizationRequest.generate(authorization.redirectUri);
    final code = await authorization.authorize(request);
    final response = await const SpotifyHttpTransport().request(
        Uri.https('accounts.spotify.com', '/api/token'),
        method: 'POST',
        form: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'redirect_uri': request.redirectUri.toString(),
          'code': code,
          'code_verifier': request.verifier,
        });
    final tokens = SpotifyTokens.fromResponse(response);
    stdout.writeln('AUTH_OK');
    for (final engine
        in (config['engines'] as List).cast<Map<String, dynamic>>()) {
      await runEngine(engine, tokens.accessToken,
          engine['trackId'] as String? ?? config['trackId'] as String, output);
    }
    stdout.writeln('PROBES_FINISHED');
  } on SpotifyException catch (error) {
    stdout.writeln('AUTH_ERROR: ${error.message}');
    exitCode = 1;
  } finally {
    authorization.cancel();
  }
}
