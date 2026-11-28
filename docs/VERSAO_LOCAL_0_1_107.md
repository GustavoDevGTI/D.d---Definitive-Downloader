# Definitive Downloader 0.1.107 (interna) — Login de plataforma na captura e motor atualizado

Versão só interna, sem release ou tag, a pedido do usuário. Instalada no Windows local.

## Problema

A captura de um reel do Instagram (`/reels/DgNfaNzo3FM/`) falhava com a mensagem genérica de análise. O motor recebia do Instagram uma "empty media response" no acesso sem login. O mesmo reel abre sem conta no navegador.

- Reproduzido com yt-dlp 2026.10.26 e 2026.11.23, com e sem `curl_cffi`, forçando o perfil Chrome e com `/reels/`, `/reel/` e `/p/`. Falhou em todos.
- A falha anônima está aberta no yt-dlp (issue #17074). O changelog da 2026.11.23 não muda o Instagram.

## Mudanças

### Motor

- yt-dlp atualizado para 2026.11.23 no Windows (`runtime/music_worker/requirements.txt`) e no Android (`runtime/music_android/requirements.txt` e lock com hash do PyPI). No lock do Android, só o yt-dlp mudou.
- `curl_cffi` corrigido no Windows. O pacote anterior tinha só a pasta vazia e as DLLs soltas, e o yt-dlp avisava que não conseguia importá-lo. Agora:
  - o build usa `--collect-all curl_cffi`;
  - `curl_cffi==0.15.0`, `yt-dlp-ejs==0.8.0` e `websockets==17.4` estão travados;
  - a publicação do motor usa `robocopy /MIR`, que não deixa arquivos do pacote anterior.
  - O Android continua sem `curl_cffi`, porque só aceita pacotes puro-Python.
- `captureAnalyze` em plataforma com login (hoje só o Instagram, `LOGIN_PLATFORMS`) devolve como resultado normal `{'loginRequired': 'instagram', 'sessionRejected': bool}`, em vez de erro. Assim funciona igual no Windows e no Android sem mexer no código nativo.
- A requisição pode levar `session`: cookies da janela de login, validados no motor (até 40, só do domínio da plataforma, nomes e valores restritos). Eles entram no cookiejar em memória do yt-dlp, sem arquivo de cookies e sem perfil de navegador. O download de áudio capturado também aceita a sessão.
- O ambiente de build agora fica em `%LOCALAPPDATA%\DownloaderDevTools\python-3.12.14-build` e `music-engine-venv`. O ambiente anterior dependia de um Python que foi removido da máquina.

### App

- `CapturePlatform` (domínio) identifica a plataforma pelo endereço e define a URL de login, o cookie de sessão (`sessionid`) e a navegação permitida (só HTTPS do domínio). Login por Facebook, Google ou Apple é bloqueado na janela, com orientação para usar usuário e senha.
- `CaptureLoginDialog` + `CaptureWebLogin` seguem o modelo da Deezer:
  - WebView privada, com perfil temporário apagado ao fechar;
  - leitura de cookies só dessa janela;
  - nada de cookies do navegador do usuário e nada de senha no chat.
- Quando a análise pede login, a janela abre sozinha. Com a sessão criada, a análise é repetida, e a janela só fecha se o conteúdo for liberado. Caso contrário, ela informa que a plataforma não liberou o conteúdo para a conta.
- A sessão aceita fica no cofre do sistema (`SecureCaptureSessionStore`, chave `dd.capture.instagram.owned-session`). Ela é reaproveitada nas próximas análises e downloads daquela plataforma e nunca é enviada a outros sites.
- Sessão recusada pela plataforma é apagada e o login é pedido de novo. **Sair do Instagram** na página de captura remove a sessão salva.
- Login cancelado: nada é capturado ou salvo.

## Validação

- Motor Python: 33 testes aprovados e 1 ignorado. Inclui os novos testes de detecção de login, cookies restritos à plataforma, sessão recusada e erros genéricos.
- Motor empacotado, com chamadas reais:
  - Instagram sem sessão devolve `loginRequired`;
  - o aviso de import do `curl_cffi` sumiu;
  - a análise de vídeo do YouTube e a busca no YouTube Music continuam funcionando.
- Dart:
  - análise sem problemas;
  - essenciais e áreas capture, downloads, connections, ui_common e matching: 131 aprovados;
  - regressão completa: 315 aprovados e 4 ignorados. A única falha foi o novo teste de download com sessão, ao apagar a pasta temporária enquanto o Windows ainda segurava o arquivo. A limpeza passou a tentar de novo, e o arquivo passou rodando junto com outros cinco sob carga.
- Novos testes Dart:
  - pedido de login, sessão errada mantendo a janela aberta, nova análise, sessão salva e reaproveitada;
  - sessão não enviada a outros sites;
  - download levando a sessão;
  - sessão recusada apagada;
  - login cancelado;
  - cookies de outro domínio recusados.
- Windows: instalador 0.1.107 instalado. App e motor instalados idênticos aos compilados, versão registrada 0.1.107, app abriu e responde.

## Limitações

- O login real no Instagram não foi feito. Ele precisa da conta do usuário. Também não está confirmado que o Instagram libera esse reel com login: há relatos no yt-dlp de posts que falham mesmo com cookies.
- Android: o código é compartilhado e o lock foi atualizado, mas não houve build de APK nem teste no emulador nesta versão.
- Não houve download real de provedor depois da atualização do yt-dlp, só análise e busca.
