import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../app/theme.dart';
import '../data/deezer_web_login.dart';
import '../domain/deezer_login_policy.dart';
import 'deezer_login_controls.dart';

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
  bool _blockedNavigation = false;
  bool _socialSignInBlocked = false;
  bool _resettingPassword = false;
  bool _verifying = false;
  int _attempt = 0;
  String? _lastSession;
  String _error = '';
  Uri? _page;
  InAppWebViewController? _view;
  Timer? _poll, _deadline, _loadTimeout;
  @override
  void initState() {
    super.initState();
    _watchLoad();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _login.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      _loadFailed(error is FormatException
          ? error.message
          : 'Não foi possível abrir o login da Deezer.');
    }
  }

  Future<void> _observe() async {
    if (_checking ||
        _finished ||
        _socialSignInBlocked ||
        _resettingPassword ||
        _error.isNotEmpty) {
      return;
    }
    final attempt = _attempt;
    _checking = true;
    try {
      final session = await _login.observe(_page);
      if (!mounted ||
          attempt != _attempt ||
          session == null ||
          session == _lastSession) {
        return;
      }
      _lastSession = session;
      setState(() => _verifying = true);
      final verified = await widget
          .verifySession(session)
          .timeout(const Duration(seconds: 30), onTimeout: () => false);
      if (!mounted || _finished || attempt != _attempt) return;
      if (verified) {
        _finished = true;
        Navigator.pop(context, session);
      } else {
        _loadFailed('A Deezer não confirmou a sessão. Entre novamente.');
      }
    } catch (_) {
      if (_verifying && attempt == _attempt) {
        _loadFailed('Não foi possível validar a sessão da Deezer.');
      }
    } finally {
      _checking = false;
      if (mounted && !_finished && _verifying) {
        setState(() => _verifying = false);
      }
    }
  }

  Future<void> _openPage(WebUri url) async {
    final view = _view;
    if (!mounted || _finished || view == null) return;
    _attempt++;
    setState(() {
      _error = '';
      _loading = true;
      _page = null;
      _lastSession = null;
      _blockedNavigation = false;
      _socialSignInBlocked = false;
      _verifying = false;
      _resettingPassword = url == DeezerWebLogin.resetUrl;
    });
    _deadline?.cancel();
    _deadline = Timer(const Duration(minutes: 5),
        () => _loadFailed('O tempo para entrar na Deezer acabou.'));
    _watchLoad();
    try {
      await view.loadUrl(urlRequest: URLRequest(url: url));
    } catch (_) {
      _loadFailed('Não foi possível abrir a página do Deezer.');
    }
  }

  void _watchLoad() {
    _loadTimeout?.cancel();
    _loadTimeout = Timer(const Duration(seconds: 30),
        () => _loadFailed('A página da Deezer demorou para responder.'));
  }

  void _loadFailed(String message) {
    if (!mounted || _finished) return;
    _loadTimeout?.cancel();
    _deadline?.cancel();
    _attempt++;
    setState(() {
      _loading = false;
      _verifying = false;
      _error = message;
    });
  }

  void _reportSocialSignIn() {
    if (!mounted || _finished || _socialSignInBlocked || _error.isNotEmpty) {
      return;
    }
    _loadTimeout?.cancel();
    _deadline?.cancel();
    _attempt++;
    setState(() {
      _socialSignInBlocked = true;
      _loading = false;
      _verifying = false;
    });
  }

  Future<void> _prepareView(InAppWebViewController view) async {
    try {
      await _login.begin(view: view);
      if (!mounted || _finished) return;
      _view = view;
      await _openPage(DeezerWebLogin.loginUrl);
      if (!mounted || _finished) return;
      _poll = Timer.periodic(
          const Duration(seconds: 1), (_) => unawaited(_observe()));
    } catch (_) {
      _loadFailed('Não foi possível preparar a janela de login.');
    }
  }

  Widget _browser() => InAppWebView(
        webViewEnvironment: _login.environment,
        initialUserScripts: UnmodifiableListView([
          UserScript(
              source: deezerLoginControls,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              forMainFrameOnly: true),
        ]),
        initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            incognito: true,
            passwordAutosaveEnabled: false,
            useShouldOverrideUrlLoading: true,
            isInspectable: false,
            transparentBackground: true,
            javaScriptCanOpenWindowsAutomatically: false,
            supportMultipleWindows: false,
            allowFileAccess: false,
            allowContentAccess: false,
            mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW),
        onWebViewCreated: _prepareView,
        onCreateWindow: (_, action) async {
          final uri = action.request.url?.uriValue;
          if (DeezerLoginPolicy.isExternalSignIn(uri) ||
              (action.hasGesture == true && uri?.scheme == 'about')) {
            _reportSocialSignIn();
          }
          // Windows forwards the target to shouldOverrideUrlLoading.
          return false;
        },
        onReceivedError: (_, request, error) {
          if (request.isForMainFrame != true) return;
          final blocked = _blockedNavigation;
          _blockedNavigation = false;
          if (error.type == WebResourceErrorType.CANCELLED ||
              (blocked &&
                  error.type == WebResourceErrorType.CONNECTION_ABORTED) ||
              error.description.contains('net::ERR_ABORTED')) {
            return;
          }
          _loadFailed('Não foi possível carregar a página do Deezer.');
        },
        onReceivedHttpError: (_, request, response) {
          final status = response.statusCode;
          if (request.isForMainFrame == true &&
              status != null &&
              status >= 400) {
            _loadFailed('O Deezer respondeu com erro HTTP $status.');
          }
        },
        shouldOverrideUrlLoading: (_, action) async {
          if (action.isForMainFrame == false ||
              DeezerLoginPolicy.allowNavigation(action.request.url?.uriValue)) {
            return NavigationActionPolicy.ALLOW;
          }
          _blockedNavigation = true;
          if (DeezerLoginPolicy.isExternalSignIn(
              action.request.url?.uriValue)) {
            _reportSocialSignIn();
          }
          return NavigationActionPolicy.CANCEL;
        },
        onLoadStart: (_, url) {
          final page = url?.uriValue;
          _page = page;
          if (!mounted ||
              _finished ||
              _socialSignInBlocked ||
              _error.isNotEmpty ||
              !DeezerLoginPolicy.allowNavigation(page)) {
            return;
          }
          setState(() {
            _loading = true;
            _resettingPassword = page!.path.contains('/forgot-password');
          });
          _watchLoad();
        },
        onLoadStop: (view, url) async {
          final page = url?.uriValue;
          if (_finished ||
              !mounted ||
              !DeezerLoginPolicy.allowNavigation(page)) {
            return;
          }
          _loadTimeout?.cancel();
          _blockedNavigation = false;
          _page = page;
          try {
            await view.evaluateJavascript(source: deezerLoginControls);
          } catch (_) {
            _loadFailed('Não foi possível preparar o formulário da Deezer. Tente novamente.');
            return;
          }
          if (!mounted || _finished) return;
          if (_loading) setState(() => _loading = false);
          await _observe();
        },
        onPermissionRequest: (_, request) async => PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.DENY),
      );

  @override
  void dispose() {
    _poll?.cancel();
    _deadline?.cancel();
    _loadTimeout?.cancel();
    _finished = true;
    unawaited(_login.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _resettingPassword
        ? 'Use o e-mail da sua conta Deezer e siga o link que chegar.'
        : 'Entre com o e-mail e a senha da Deezer.';
    final waiting = _loading || _verifying;
    return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        clipBehavior: Clip.antiAlias,
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
            width: 820,
            height: 740,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
                      child: Row(children: [
                        const Expanded(
                            child: Text('Conectar Deezer',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700))),
                        IconButton(
                            tooltip: 'Fechar conexão Deezer',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded)),
                      ])),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                      child: Row(children: [
                        Expanded(
                            child: Semantics(
                                liveRegion: true,
                                child: Text(status,
                                    style: const TextStyle(
                                        color: AppColors.muted)))),
                        if (_view != null &&
                            !_verifying &&
                            !_socialSignInBlocked)
                          TextButton(
                              onPressed: () => unawaited(_openPage(
                                  _resettingPassword
                                      ? DeezerWebLogin.loginUrl
                                      : DeezerWebLogin.resetUrl)),
                              child: Text(_resettingPassword
                                  ? 'Voltar ao login'
                                  : 'Definir senha')),
                      ])),
                  SizedBox(
                      height: 2,
                      child: waiting
                          ? LinearProgressIndicator(
                              color: AppColors.accent,
                              backgroundColor: AppColors.line,
                              semanticsLabel: _verifying
                                  ? 'Validando sessão'
                                  : 'Carregando Deezer')
                          : const ColoredBox(color: AppColors.line)),
                  Expanded(
                      child: ClipRect(
                          child: Stack(fit: StackFit.expand, children: [
                    if (_ready)
                      Offstage(
                          offstage: _error.isNotEmpty || _socialSignInBlocked,
                          child: _browser()),
                    if (_error.isNotEmpty ||
                        _view == null ||
                        _socialSignInBlocked)
                      Center(
                          child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_socialSignInBlocked && _error.isEmpty)
                                      const SizedBox(
                                          width: 360,
                                          child: Text(
                                              'Use o mesmo e-mail do Google com a sua senha Deezer. Se precisar, defina a senha pelo e-mail da conta.',
                                              textAlign: TextAlign.center))
                                    else
                                      Text(
                                          _error.isEmpty
                                              ? 'Abrindo a Deezer…'
                                              : _error,
                                          textAlign: TextAlign.center),
                                    if (_view != null) ...[
                                      const SizedBox(height: 12),
                                      if (_socialSignInBlocked &&
                                          _error.isEmpty)
                                        Wrap(
                                            alignment: WrapAlignment.center,
                                            spacing: 8,
                                            children: [
                                              TextButton(
                                                  onPressed: () => unawaited(
                                                      _openPage(DeezerWebLogin
                                                          .loginUrl)),
                                                  child: const Text(
                                                      'Voltar ao login')),
                                              FilledButton(
                                                  onPressed: () => unawaited(
                                                      _openPage(DeezerWebLogin
                                                          .resetUrl)),
                                                  child: const Text(
                                                      'Definir senha')),
                                            ])
                                      else
                                        FilledButton(
                                            onPressed: () => unawaited(
                                                _openPage(_resettingPassword
                                                    ? DeezerWebLogin.resetUrl
                                                    : DeezerWebLogin.loginUrl)),
                                            child:
                                                const Text('Tentar novamente')),
                                    ],
                                  ]))),
                  ]))),
                ])));
  }
}
