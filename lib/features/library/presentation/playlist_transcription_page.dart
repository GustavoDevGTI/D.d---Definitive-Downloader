import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/application/operation_message.dart';
import '../../connections/domain/music_account.dart';
import '../../downloads/download_cancellation.dart';
import '../../importing/playlist_transcription.dart';
import '../application/library_controller.dart';

Future<PlaylistTranscription?> showPlaylistTranscription(
        BuildContext context, LibraryController library, String initialLink) =>
    showDialog<PlaylistTranscription>(
        context: context,
        builder: (_) => _PlaylistTranscriptionPage(library, initialLink));

class _PlaylistTranscriptionPage extends StatefulWidget {
  const _PlaylistTranscriptionPage(this.library, this.initialLink);

  final LibraryController library;
  final String initialLink;

  @override
  State<_PlaylistTranscriptionPage> createState() =>
      _PlaylistTranscriptionPageState();
}

class _PlaylistTranscriptionPageState
    extends State<_PlaylistTranscriptionPage> {
  final _html = rootBundle.loadString('assets/playlist/transcription.html');
  DownloadCancellation? _reading;
  PlaylistTranscription? _transcription;
  String? _transcribedLink;
  bool _closing = false;

  @override
  void dispose() {
    _reading?.cancelled = true;
    super.dispose();
  }

  bool get _active =>
      mounted && !_closing && ModalRoute.of(context)?.isCurrent == true;

  Future<Object?> _handle(JavaScriptHandlerFunctionData data) async {
    final args = data.args;
    if (!_active ||
        !data.isMainFrame ||
        !const {'about', 'data'}.contains(data.requestUrl.scheme) ||
        args.isEmpty) {
      return null;
    }
    if (args.length == 1 && args.first == 'initial') return widget.initialLink;
    if (args.length != 2 || args.last is! String) return null;
    final link = (args.last as String).trim();
    if (args.first == 'read') return _read(link);
    if (args.first == 'confirm' &&
        _reading == null &&
        link == _transcribedLink &&
        _transcription != null &&
        !widget.library.busy) {
      _closing = true;
      Navigator.pop(context, _transcription);
      return true;
    }
    return false;
  }

  Future<Map<String, Object?>> _read(String link) async {
    if (_reading != null) {
      return {'error': 'Aguarde a leitura da playlist.'};
    }
    final cancellation = _reading = DownloadCancellation();
    _transcription = null;
    _transcribedLink = null;
    try {
      final transcription =
          await widget.library.transcribePlaylist(link, cancellation);
      if (!_active || cancellation.cancelled) {
        return {'error': 'Leitura cancelada.'};
      }
      _transcription = transcription;
      _transcribedLink = link;
      return {
        'name': transcription.name,
        'source': transcription.source,
        'total': transcription.tracks.length,
        'tracks': [
          for (final track in transcription.tracks.take(8))
            {'title': track.title, 'artist': track.artist}
        ],
      };
    } on MusicAccountRequired {
      return {
        'error': 'Conecte uma conta com acesso à playlist e tente de novo.'
      };
    } on DownloadCancelled {
      return {'error': 'Leitura cancelada.'};
    } on FormatException catch (error) {
      return {'error': operationMessage(error)};
    } catch (_) {
      return {'error': 'A origem não entregou a playlist. Tente novamente.'};
    } finally {
      _reading = null;
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 760,
          height: 650,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Fechar transcrição',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: FutureBuilder<String>(
                  future: _html,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text('Não foi possível abrir a transcrição.'));
                    }
                    final html = snapshot.data;
                    if (html == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return InAppWebView(
                      initialData: InAppWebViewInitialData(data: html),
                      initialSettings: InAppWebViewSettings(
                        allowFileAccess: false,
                        allowContentAccess: false,
                        isInspectable: false,
                        javaScriptHandlersForMainFrameOnly: true,
                        javaScriptCanOpenWindowsAutomatically: false,
                        supportMultipleWindows: false,
                        useShouldOverrideUrlLoading: true,
                      ),
                      onWebViewCreated: (web) => web.addJavaScriptHandler(
                          handlerName: 'ddPlaylist', callback: _handle),
                      shouldOverrideUrlLoading: (_, action) async =>
                          action.request.url?.toString() == 'about:blank'
                              ? NavigationActionPolicy.ALLOW
                              : NavigationActionPolicy.CANCEL,
                      onCreateWindow: (_, __) async => false,
                      onLoadStop: (web, _) async => web.evaluateJavascript(
                          source:
                              'if (typeof initialize === "function") initialize();'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
}
