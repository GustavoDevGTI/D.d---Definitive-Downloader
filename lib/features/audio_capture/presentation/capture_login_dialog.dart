import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../app/theme.dart';
import '../../../core/web/password_login_only.dart';
import '../data/capture_web_login.dart';
import '../domain/capture_login.dart';

/// Login of a capture platform inside the app. Returns the session only after
/// [verify] accepted it.
Future<List<SessionCookie>?> showCaptureLogin(
        BuildContext context,
        CapturePlatform platform,
        Future<bool> Function(List<SessionCookie>) verify) =>
    showDialog<List<SessionCookie>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CaptureLoginDialog(platform: platform, verify: verify));

class CaptureLoginDialog extends StatefulWidget {
  const CaptureLoginDialog(
      {super.key, required this.platform, required this.verify});
  final CapturePlatform platform;
  final Future<bool> Function(List<SessionCookie>) verify;
  @override
  State<CaptureLoginDialog> createState() => _CaptureLoginDialogState();
}

class _CaptureLoginDialogState extends State<CaptureLoginDialog> {
  late final _login = CaptureWebLogin(widget.platform);
  // Facebook, Google and Apple buttons are disabled inside the page itself.
  late final _controls = passwordLoginOnly(widget.platform.domains,
      ownBrands: widget.platform.ownBrands);
  bool _ready = false, _loading = true, _verifying = false, _finished = false;
  bool _checking = false, _external = false;
  String _error = '';
  String? _lastSession;
  Uri? _page;
  InAppWebViewController? _view;
  Timer? _poll, _deadline;

  String get _label => widget.platform.label;

  @override
  void initState() {
    super.initState();
    _deadline = Timer(const Duration(minutes: 10),
        () => _fail('O tempo para entrar no $_label acabou.'));
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _login.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      _fail(error is FormatException
          ? error.message
          : 'Não foi possível abrir o login do $_label.');
    }
  }

  void _fail(String message) {
    if (!mounted || _finished) return;
    setState(() {
      _loading = false;
      _verifying = false;
      _error = message;
    });
  }

  Future<void> _observe() async {
    if (_checking || _finished || _verifying || _error.isNotEmpty) return;
    _checking = true;
    try {
      final session = await _login.observe(_page);
      if (!mounted || session == null) return;
      final key = session
          .where((c) => c.name == widget.platform.sessionCookie)
          .map((c) => c.value)
          .join();
      if (key == _lastSession) return;
      _lastSession = key;
      setState(() => _verifying = true);
      final accepted = await widget
          .verify(session)
          .timeout(const Duration(seconds: 90), onTimeout: () => false);
      if (!mounted || _finished) return;
      if (accepted) {
        _finished = true;
        Navigator.pop(context, session);
      } else {
        _fail('O $_label não liberou este conteúdo para esta conta.');
      }
    } catch (_) {
      _fail('Não foi possível confirmar o login no $_label. Tente novamente.');
    } finally {
      _checking = false;
      if (mounted && !_finished && _verifying) {
        setState(() => _verifying = false);
      }
    }
  }

  Future<void> _retry() async {
    final view = _view;
    if (view == null) return;
    setState(() {
      _error = '';
      _external = false;
      _loading = true;
      _lastSession = null;
    });
    try {
      await view.loadUrl(urlRequest: URLRequest(url: _login.loginUrl));
    } catch (_) {
      _fail('Não foi possível abrir a página do $_label.');
    }
  }

  Future<void> _prepare(InAppWebViewController view) async {
    try {
      await _login.begin(view);
      if (!mounted || _finished) return;
      _view = view;
      await view.loadUrl(urlRequest: URLRequest(url: _login.loginUrl));
      _poll = Timer.periodic(
          const Duration(seconds: 1), (_) => unawaited(_observe()));
    } catch (_) {
      _fail('Não foi possível preparar a janela de login.');
    }
  }

  Widget _browser() => InAppWebView(
        webViewEnvironment: _login.environment,
        initialUserScripts: UnmodifiableListView([
          UserScript(
              source: _controls,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: true),
        ]),
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
            mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW),
        onWebViewCreated: _prepare,
        onCreateWindow: (_, action) async {
          if (widget.platform.isExternalSignIn(action.request.url?.uriValue)) {
            setState(() => _external = true);
          }
          return false;
        },
        shouldOverrideUrlLoading: (_, action) async {
          final target = action.request.url?.uriValue;
          if (action.isForMainFrame == false ||
              widget.platform.allowsNavigation(target)) {
            return NavigationActionPolicy.ALLOW;
          }
          if (widget.platform.isExternalSignIn(target) && mounted) {
            setState(() => _external = true);
          }
          return NavigationActionPolicy.CANCEL;
        },
        onLoadStart: (_, url) {
          _page = url?.uriValue;
          if (mounted && !_loading) setState(() => _loading = true);
        },
        onLoadStop: (view, url) async {
          _page = url?.uriValue;
          if (!widget.platform.allowsNavigation(_page)) return;
          try {
            await view.evaluateJavascript(source: _controls);
          } catch (_) {
            _fail(
                'Não foi possível preparar o login do $_label. Tente novamente.');
            return;
          }
          if (mounted && _loading) setState(() => _loading = false);
          await _observe();
        },
        onReceivedError: (_, request, error) {
          if (request.isForMainFrame != true ||
              error.type == WebResourceErrorType.CANCELLED ||
              error.description.contains('net::ERR_ABORTED')) {
            return;
          }
          _fail('Não foi possível carregar a página do $_label.');
        },
        onPermissionRequest: (_, request) async => PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.DENY),
      );

  @override
  void dispose() {
    _poll?.cancel();
    _deadline?.cancel();
    _finished = true;
    unawaited(_login.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _verifying
        ? 'Login feito. Conferindo o conteúdo…'
        : _external
            ? 'Use o usuário e a senha do $_label. O login por outra empresa não abre nesta janela.'
            : 'Entre com o usuário e a senha do $_label. A sessão fica só neste aparelho.';
    return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        clipBehavior: Clip.antiAlias,
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
            width: 520,
            height: 760,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
                      child: Row(children: [
                        Expanded(
                            child: Text('Entrar no $_label',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700))),
                        IconButton(
                            key: const ValueKey('capture-login-close'),
                            tooltip: 'Cancelar login',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded)),
                      ])),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Semantics(
                          liveRegion: true,
                          child: Text(status,
                              style: const TextStyle(color: AppColors.muted)))),
                  SizedBox(
                      height: 2,
                      child: _loading || _verifying
                          ? const LinearProgressIndicator(
                              color: AppColors.accent,
                              backgroundColor: AppColors.line)
                          : const ColoredBox(color: AppColors.line)),
                  Expanded(
                      child: Stack(fit: StackFit.expand, children: [
                    if (_ready)
                      Offstage(offstage: _error.isNotEmpty, child: _browser()),
                    if (_error.isNotEmpty || _view == null)
                      Center(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                        _error.isEmpty
                                            ? 'Abrindo o $_label…'
                                            : _error,
                                        textAlign: TextAlign.center),
                                    if (_error.isNotEmpty && _view != null) ...[
                                      const SizedBox(height: 12),
                                      FilledButton(
                                          onPressed: () => unawaited(_retry()),
                                          child:
                                              const Text('Tentar novamente')),
                                    ],
                                  ]))),
                  ])),
                ])));
  }
}
