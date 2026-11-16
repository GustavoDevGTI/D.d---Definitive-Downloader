import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';

class SpotifyPlaylistVisibilityDialog extends StatefulWidget {
  const SpotifyPlaylistVisibilityDialog(
      {super.key, required this.playlistId, required this.retryImport});

  final String playlistId;
  final Future<bool> Function() retryImport;

  @override
  State<SpotifyPlaylistVisibilityDialog> createState() =>
      _SpotifyPlaylistVisibilityDialogState();
}

class _SpotifyPlaylistVisibilityDialogState
    extends State<SpotifyPlaylistVisibilityDialog> {
  Timer? _guideTimer;
  Timer? _loadTimer;
  InAppWebViewController? _web;
  Widget? _webView;
  bool _showWeb = false;
  bool _loading = true;
  bool _webFailed = false;
  bool _retrying = false;
  bool _stillUnavailable = false;

  Uri get _playlist =>
      Uri.https('open.spotify.com', '/playlist/${widget.playlistId}');
  Uri get _signIn => Uri.https(
      'accounts.spotify.com', '/login', {'continue': _playlist.toString()});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_guideTimer != null || _webView != null) return;
    _guideTimer = Timer(
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 2700),
        _openWeb);
  }

  void _openWeb() {
    _guideTimer?.cancel();
    if (_webView == null) _startLoadTimeout();
    setState(() {
      _webView ??= _spotifyWeb(context);
      _showWeb = true;
    });
  }

  void _startLoadTimeout() {
    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(seconds: 25), _failWeb);
  }

  void _failWeb() {
    _loadTimer?.cancel();
    if (mounted) setState(() => _webFailed = true);
  }

  Future<void> _retry() async {
    setState(() {
      _retrying = true;
      _stillUnavailable = false;
    });
    final inaccessible = await widget.retryImport();
    if (!mounted) return;
    if (!inaccessible) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _retrying = false;
      _stillUnavailable = true;
    });
  }

  static bool _allowsNavigation(Uri? uri) =>
      uri != null &&
      uri.scheme == 'https' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      (uri.host == 'accounts.spotify.com' || uri.host == 'open.spotify.com');

  Future<void> _openBrowser() async {
    await launchUrl(_playlist, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _guideTimer?.cancel();
    _loadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_retrying,
        child: Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 960,
            height: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                  child: Row(children: [
                    Expanded(
                      child: Text('Torne a playlist pública',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed:
                          _retrying ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ]),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                      'O link não está acessível. Se a playlist for sua, entre no Spotify, abra a playlist e escolha ⋯ → Tornar pública.'),
                ),
                if (_retrying || (_showWeb && _loading && !_webFailed))
                  const LinearProgressIndicator(minHeight: 2)
                else
                  const Divider(height: 2),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_webView != null)
                        Offstage(
                          offstage: !_showWeb || _webFailed,
                          child: _webView!,
                        ),
                      if (_showWeb && _webFailed)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: const Text(
                                'Não foi possível carregar o Spotify nesta janela. Abra a playlist no navegador e volte para importar.'),
                          ),
                        ),
                      if (!_showWeb) const _SpotifyMenuGuide(),
                    ],
                  ),
                ),
                Visibility(
                  visible: _stillUnavailable,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Semantics(
                        liveRegion: true,
                        child: const Text(
                            'O link ainda está inacessível. Confira se a playlist ficou pública e se o link está correto.')),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (_showWeb) ...[
                        TextButton(
                            onPressed: _retrying
                                ? null
                                : () => setState(() => _showWeb = false),
                            child: const Text('Ver guia')),
                        TextButton(
                            onPressed: _retrying || _web == null || _webFailed
                                ? null
                                : () => _web!.loadUrl(
                                    urlRequest:
                                        URLRequest(url: WebUri.uri(_playlist))),
                            child: const Text('Abrir playlist')),
                        TextButton(
                            onPressed: _retrying ? null : _openBrowser,
                            child: const Text('Abrir no navegador')),
                        FilledButton(
                            onPressed: _retrying ? null : _retry,
                            child: Text(_retrying
                                ? 'Importando…'
                                : 'Tentar importar novamente')),
                      ] else
                        FilledButton(
                            onPressed: _openWeb,
                            child: const Text('Abrir Spotify Web')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _spotifyWeb(BuildContext context) => InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri.uri(_signIn)),
        initialSettings: InAppWebViewSettings(
          useShouldOverrideUrlLoading: true,
          incognito: Theme.of(context).platform == TargetPlatform.windows,
          javaScriptBridgeEnabled: false,
          isInspectable: false,
          allowFileAccess: false,
          allowContentAccess: false,
          javaScriptCanOpenWindowsAutomatically: false,
          supportMultipleWindows: true,
          passwordAutosaveEnabled: false,
          generalAutofillEnabled: false,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
        ),
        onWebViewCreated: (view) {
          if (mounted) setState(() => _web = view);
        },
        shouldOverrideUrlLoading: (_, action) async =>
            action.isForMainFrame == false ||
                    _allowsNavigation(action.request.url?.uriValue)
                ? NavigationActionPolicy.ALLOW
                : NavigationActionPolicy.CANCEL,
        onCreateWindow: (_, __) async => false,
        onPermissionRequest: (_, request) async => PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.DENY),
        onLoadStart: (_, __) {
          if (!mounted) return;
          _startLoadTimeout();
          setState(() => _loading = true);
        },
        onLoadStop: (_, __) {
          _loadTimer?.cancel();
          if (mounted) {
            setState(() {
              _loading = false;
              _webFailed = false;
            });
          }
        },
        onReceivedError: (_, request, __) {
          if (mounted && request.isForMainFrame == true) {
            _failWeb();
          }
        },
        onReceivedHttpError: (_, request, __) {
          if (mounted &&
              request.isForMainFrame == true &&
              request.url.host == 'accounts.spotify.com') {
            _failWeb();
          }
        },
      );
}

class _SpotifyMenuGuide extends StatelessWidget {
  const _SpotifyMenuGuide();

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 2350),
            builder: (_, progress, __) => Card(
              color: AppColors.navigation,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      const Expanded(
                        child: Text('Menu da playlist',
                            style: TextStyle(color: Colors.white)),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: progress < .32
                                ? AppColors.accentActive
                                : Colors.white12),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.more_horiz, color: Colors.white),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: ((progress - .22) * 10).clamp(0.0, 1.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _MenuItem(
                              Icons.edit_outlined, 'Editar os detalhes'),
                          const Divider(color: Colors.white24),
                          _MenuItem(Icons.language, 'Tornar pública',
                              highlighted: progress >= .55),
                          const _MenuItem(Icons.share_outlined, 'Compartilhar'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem(this.icon, this.label, {this.highlighted = false});

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: highlighted ? AppColors.accentActive : Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Flexible(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      );
}
