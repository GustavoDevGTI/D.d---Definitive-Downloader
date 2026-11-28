# Definitive Downloader 0.1.109 (interna) — Plataformas sociais na captura de áudio

Versão só interna, sem release ou tag.

## Avaliação sem login (27/11/2026, yt-dlp 2026.11.23, código de captura do motor)

| Plataforma | Resultado sem login | Login no app |
|---|---|---|
| X/Twitter | 5 de 5 tweets públicos com vídeo extraídos. Tweets sem vídeo dão "No video could be found". | Sob demanda: tweets sensíveis ou de contas protegidas pedem autenticação. |
| Instagram | 2 de 2 posts antigos extraídos. O reel do usuário (`/reels/DgNfaNzo3FM/`) exige login. | Sob demanda (desde a 0.1.107). |
| TikTok | 2 de 3 extraídos. 1 bloqueado por região/IP, o que o login não resolve. | Sob demanda: posts com restrição de idade pedem login. |
| Facebook | Reel público extraído; 2 vídeos pedem login ("No video found… logged-in"). | Sob demanda. |
| Bluesky | Post público extraído (o outro de teste foi apagado, HTTP 400). | Não precisa. |
| Pinterest | 3 de 3 pins extraídos. | Não precisa. |
| Threads | A página é pública, mas o yt-dlp não tem extrator de Threads: "Unsupported URL", inclusive no extrator genérico. | Login não resolve. Precisa de um extrator próprio (tarefa separada). |
| Status Saver (WhatsApp) | Não é site. Os status vistos ficam no celular em `Android/media/com.whatsapp/WhatsApp/Media/.Statuses` (e `com.whatsapp.w4b` no Business) por cerca de 24 h. No Windows, o WhatsApp Desktop não deixa esses arquivos acessíveis. | Não usa login. Só é viável no Android, escolhendo essa pasta pelo seletor do sistema e extraindo o áudio dos vídeos (tarefa separada). |

## Mudanças

- Motor: `LOGIN_PLATFORMS` passa a ter `twitter` (x.com, twitter.com), `tiktok` (tiktok.com) e `facebook` (facebook.com, fb.watch), além de `instagram`.
  - As mensagens que pedem login foram ampliadas com "log in", "logged in", "requires authentication" etc., e valem só para essas plataformas.
  - Bloqueio por IP e "sem vídeo" continuam como erro comum.
  - Até 60 cookies por sessão.
- App: `CapturePlatform` tem, por plataforma, domínios, página de login, URLs de cookie, cookie de sessão e as marcas próprias:
  - Instagram: `sessionid`;
  - X: `auth_token`;
  - TikTok: `sessionid`;
  - Facebook: `c_user`.
  - A sessão guarda o cookie de login primeiro e fica limitada a 60 cookies e cerca de 20 mil caracteres, dentro do limite da requisição ao motor.
- O fluxo é o mesmo do Instagram: a janela privada abre sozinha quando o post pede login, repete a análise e guarda a sessão no cofre. Sessão recusada é apagada.
- Bloqueador compartilhado (`lib/core/web/password_login_only.dart`):
  - recebe a lista de provedores a bloquear, sem a marca da própria plataforma (no Facebook, os links do Facebook continuam ativos);
  - passou a cobrir iframes de login de terceiros, como o botão do Google no X;
  - a lista padrão ganhou Instagram, Kakao e LINE;
  - a Deezer usa a lista padrão, com o mesmo instalador.
- Conexões: nova seção **Captura de áudio**, uma linha por plataforma, com estado e **Entrar no …**/**Sair do …**, no padrão do painel Deezer.
  - Entrando por ali, o login é aceito quando aparece o cookie de sessão na página da plataforma. O conteúdo é conferido depois, na captura.
  - A página de captura relê as sessões no início de cada análise.

## Validação

- Motor Python: 36 testes aprovados e 1 ignorado. Novos testes cobrem os domínios das plataformas, as mensagens de login por plataforma, IP bloqueado e "sem vídeo" sem pedir login, e cookies de outra plataforma recusados.
- Dart:
  - análise sem problemas;
  - áreas connections, capture e ui_common: 69 aprovados;
  - `password_login_only_test` cobre domínios, marcas próprias, Deezer padrão e sessão grande com o cookie de login preservado.
- Uma corrida real foi corrigida. A releitura das sessões no início da análise rodava sem esperar e podia trazer de volta uma sessão recusada. Agora ela termina antes da análise.
- Páginas reais de login, no navegador interno e sem conta, com o regex gerado para cada plataforma:
  - X: Google (botão e iframe) e Apple bloqueados; telefone e campo de usuário ativos.
  - TikTok (login por e-mail): nada bloqueado; só há campos, Entrar, Esqueceu a senha e Inscrever-se.
  - Facebook: só o link "Instagram" do rodapé bloqueado; Entrar, Esqueceu a senha e Criar conta ativos.
  - Instagram: verificado na 0.1.108.
- Motor recompilado: tweet público do X extraído e reel do Instagram devolvendo `loginRequired`.
- Windows: 0.1.109 instalada, app e motor idênticos aos compilados. `--check-login-webview` (WebView2 real, sem conta) passou com o bloqueador novo, e o app abriu.

## Limitações

- Nenhum login real foi feito. Também não foi verificado que cada plataforma libera, com login, os posts que pediram conta.
- Threads e Status Saver não foram implementados; estão descritos acima.
- Android: código compartilhado, mas sem APK nem teste nativo nesta versão, por estar aguardando o emulador da Galeria.
