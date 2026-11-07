import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../data/deezer_web_login.dart';
import '../domain/deezer_login_policy.dart';

Future<String?> showDeezerLogin(BuildContext context,
        {required Future<bool> Function(String) verifySession}) =>
    showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DeezerLoginDialog(verifySession: verifySession));

class DeezerLoginDialog extends StatefulWidget {
  const DeezerLoginDialog({super.key, required this.verifySession});
  final Future<bool> Function(String) verifySession;
  @override
  State<DeezerLoginDialog> createState() => _DeezerLoginDialogState();
}

class _DeezerLoginDialogState extends State<DeezerLoginDialog> {
  final _login = DeezerWebLogin();
  bool _ready = false, _loading = true, _finished = false;
  bool _checking = false;
  String? _lastSession;
  String _error = '';
  Uri? _page;
  Timer? _poll, _deadline;
  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
    _deadline = Timer(const Duration(minutes: 5), () {
      _finished = true;
      if (mounted) {
        setState(() => _error = 'O login expirou. Feche e tente novamente.');
      }
      _poll?.cancel();
    });
  }

  Future<void> _initialize() async {
    try {
      await _login.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is FormatException
            ? error.message
            : 'Não foi possível abrir o login Deezer. Confira o WebView do sistema.');
      }
    }
  }

  Future<void> _observe() async {
    if (_checking || _finished) return;
    _checking = true;
    try {
      final session = await _login.observe(_page);
      if (session == null || session == _lastSession) return;
      _lastSession = session;
      final verified = await widget.verifySession(session);
      if (mounted && !_finished && verified) {
        _finished = true;
        Navigator.pop(context, session);
      }
    } catch (_) {
      /* Navigation may detach the view during a cookie query. */
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _deadline?.cancel();
    unawaited(_login.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
          width: 900,
          height: 700,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(children: [
                  const Expanded(child: Text('Entrar na Deezer')),
                  if (_error.isEmpty)
                    IconButton(
                        tooltip: 'Reverificar login',
                        onPressed: () {
                          _lastSession = null;
                          unawaited(_observe());
                        },
                        icon: const Icon(Icons.refresh)),
                  IconButton(
                      tooltip: 'Cancelar login',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close))
                ])),
            if (_loading && _error.isEmpty)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
                child: _error.isNotEmpty
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error)))
                    : !_ready
                        ? const SizedBox()
                        : InAppWebView(
                            webViewEnvironment: _login.environment,
                            initialSettings: InAppWebViewSettings(
                                javaScriptEnabled: true,
                                incognito: true,
                                passwordAutosaveEnabled: false,
                                useShouldOverrideUrlLoading: true,
                                isInspectable: false,
                                javaScriptCanOpenWindowsAutomatically: false,
                                supportMultipleWindows: false,
                                allowFileAccess: false,
                                allowContentAccess: false,
                                mixedContentMode:
                                    MixedContentMode.MIXED_CONTENT_NEVER_ALLOW),
                            onWebViewCreated: (view) async {
                              try {
                                await _login.begin(view: view);
                                if (!mounted) return;
                                await view.loadUrl(
                                    urlRequest: URLRequest(
                                        url: DeezerWebLogin.loginUrl));
                                _poll = Timer.periodic(
                                    const Duration(seconds: 1),
                                    (_) => unawaited(_observe()));
                              } catch (_) {
                                if (mounted) {
                                  setState(() => _error =
                                      'Não foi possível preparar a janela de login. Feche e tente novamente.');
                                }
                              }
                            },
                            onReceivedError: (_, request, error) {
                              if (mounted && request.isForMainFrame == true) {
                                setState(() => _error =
                                    'Não foi possível carregar o login. Confira a conexão e tente novamente.');
                              }
                            },
                            shouldOverrideUrlLoading: (_, action) async =>
                                action.isForMainFrame == false ||
                                        DeezerLoginPolicy.allowNavigation(
                                            action.request.url?.uriValue)
                                    ? NavigationActionPolicy.ALLOW
                                    : NavigationActionPolicy.CANCEL,
                            onLoadStart: (_, url) {
                              _page = url?.uriValue;
                            },
                            onLoadStop: (_, url) async {
                              _page = url?.uriValue;
                              if (mounted) setState(() => _loading = false);
                              await _observe();
                            },
                            onPermissionRequest: (_, request) async =>
                                PermissionResponse(
                                    resources: request.resources,
                                    action: PermissionResponseAction.DENY),
                          )),
          ])));
}
