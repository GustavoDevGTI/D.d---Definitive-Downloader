# Definitive Downloader 0.1.108 (interna) — Login social bloqueado na página do Instagram

Versão só interna, sem release ou tag.

## Mudança

- A janela de login do Instagram desativa na própria página os botões e links de outros provedores (Facebook, Google, Apple etc.), como a da Deezer desde a 0.1.96. Eles ficam apagados, sem foco por teclado, e cliques e Enter neles são interceptados.
- O bloqueio de navegação para fora do Instagram (0.1.107) continua como segunda barreira.
- O script passou a ser compartilhado em `lib/core/web/password_login_only.dart`:
  - `socialSignInBlocker` é o mesmo conteúdo de antes;
  - `passwordLoginOnly(domínio)` só roda em HTTPS do domínio e subdomínios.
  - A Deezer usa o mesmo módulo e o mesmo script de antes (`deezerLoginControlInstaller` e `deezerLoginControls`).
- O script é injetado no início do documento e de novo ao fim de cada carregamento. Ele não lê campos, cookies ou credenciais.
- O texto da janela agora orienta a usar o usuário e a senha do Instagram.

## Validação

- Na página real de login do Instagram, no navegador interno e sem conta:
  - "Entrar com o Facebook" ficou desativado e o clique não saiu da página;
  - campos, "Entrar" e "Esqueceu a senha?" não foram alterados pelo script. O "Entrar" já vem desativado pelo Instagram até preencher os campos.
  - Links do rodapé que apontam para o Facebook também ficam desativados.
- `password_login_only_test` (novo, área connections): garante a restrição por domínio e que a Deezer continua com o mesmo script.
- Análise sem problemas e áreas connections e capture com 57 testes aprovados.
- Windows: 0.1.108 instalada, binário idêntico ao compilado, app abriu e responde.
- Diagnóstico nativo Windows `--check-login-webview` (WebView2 real, sem conta) passou com código 0 no build 0.1.108. Ele confirma que o bloqueador compartilhado desativa Google, Facebook e Apple, preserva o botão de e-mail e recusa cookie de domínio falso.
- Não validado: login real com conta.
