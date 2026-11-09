import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../data/spotify_web_profile.dart';
import '../domain/spotify_auth.dart';

Future<Uri?> showSpotifyLogin(BuildContext context,
        SpotifyAuthorizationRequest request, Future<void> cancelled) =>
    showDialog<Uri>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SpotifyLoginDialog(request, cancelled));

class _SpotifyLoginDialog extends StatefulWidget {
  const _SpotifyLoginDialog(this.request, this.cancelled);
  final SpotifyAuthorizationRequest request;
  final Future<void> cancelled;

  @override
  State<_SpotifyLoginDialog> createState() => _SpotifyLoginDialogState();
}

class _SpotifyLoginDialogState extends State<_SpotifyLoginDialog> {
  final _profile = SpotifyWebProfile();
  late final Future<WebViewEnvironment> _environment;
  bool _loading = true, _closing = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _environment = _profile.open();
    unawaited(widget.cancelled.then((_) => _finish(null)));
  }

  @override
  void dispose() {
    unawaited(_environment
        .then<void>((_) {}, onError: (Object _) {})
        .whenComplete(_profile.close));
    super.dispose();
  }

  void _finish(Uri? callback) {
    if (!mounted || _closing || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _closing = true;
    Navigator.pop(context, callback);
  }

  NavigationActionPolicy _navigation(Uri? uri) {
    if (_closing || uri == null) return NavigationActionPolicy.CANCEL;
    final redirect = widget.request.redirectUri;
    if (uri.scheme == redirect.scheme &&
        uri.host == redirect.host &&
        uri.port == redirect.port &&
        uri.path == redirect.path) {
      try {
        widget.request.acceptCallback(uri);
        _finish(uri);
      } on SpotifyAuthCancelled {
        _finish(null);
      } on SpotifyException catch (error) {
        if (mounted) setState(() => _message = error.message);
      }
      return NavigationActionPolicy.CANCEL;
    }
    if (uri.scheme == 'https' &&
        uri.port == 443 &&
        uri.userInfo.isEmpty &&
        uri.host == 'accounts.spotify.com') {
      if (_message.isNotEmpty && mounted) setState(() => _message = '');
      return NavigationActionPolicy.ALLOW;
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _message =
            'Escolha um método de entrada oferecido diretamente pelo Spotify nesta janela.';
      });
    }
    return NavigationActionPolicy.CANCEL;
  }

  @override
  Widget build(BuildContext context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
          width: 820,
          height: 700,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(children: [
                  const Expanded(child: Text('Conectar Spotify')),
                  IconButton(
                      tooltip: 'Cancelar login Spotify',
                      onPressed: () => _finish(null),
                      icon: const Icon(Icons.close))
                ])),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_message.isNotEmpty)
              Padding(padding: const EdgeInsets.all(12), child: Text(_message)),
            Expanded(
                child: FutureBuilder<WebViewEnvironment>(
                    future: _environment,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                            child: Text(
                                'Não foi possível abrir o login Spotify. Confira o WebView2 do Windows.'));
                      }
                      final environment = snapshot.data;
                      if (environment == null) return const SizedBox.shrink();
                      return InAppWebView(
                          webViewEnvironment: environment,
                          initialUrlRequest: URLRequest(
                              url: WebUri.uri(widget.request.authorizationUri)),
                          initialSettings: InAppWebViewSettings(
                              incognito: true,
                              passwordAutosaveEnabled: false,
                              browserAcceleratorKeysEnabled: false,
                              useShouldOverrideUrlLoading: true,
                              isInspectable: false,
                              javaScriptCanOpenWindowsAutomatically: false,
                              supportMultipleWindows: false,
                              allowFileAccess: false,
                              allowContentAccess: false,
                              mixedContentMode:
                                  MixedContentMode.MIXED_CONTENT_NEVER_ALLOW),
                          shouldOverrideUrlLoading: (_, action) async =>
                              action.isForMainFrame == false
                                  ? NavigationActionPolicy.ALLOW
                                  : _navigation(action.request.url?.uriValue),
                          onCreateWindow: (_, __) async => false,
                          onLoadStop: (_, __) {
                            if (mounted) setState(() => _loading = false);
                          },
                          onReceivedError: (_, request, __) {
                            if (!mounted ||
                                _closing ||
                                request.isForMainFrame != true) {
                              return;
                            }
                            setState(() {
                              _loading = false;
                              _message =
                                  'Não foi possível carregar a página do Spotify.';
                            });
                          },
                          onPermissionRequest: (_, request) async =>
                              PermissionResponse(
                                  resources: request.resources,
                                  action: PermissionResponseAction.DENY));
                    })),
          ])));
}
