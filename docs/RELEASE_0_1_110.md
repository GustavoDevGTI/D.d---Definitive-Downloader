# Definitive Downloader 0.1.110 — Windows e Android

Junta as versões locais 0.1.106 a 0.1.110: uma página Capturar áudio nova, escolha da pasta de cada playlist, login dentro do app para X, Instagram, TikTok e Facebook na captura, e o Status do WhatsApp no Android. Instalador Windows x64 e APK Android ARM64 da mesma versão.

## Capturar áudio

- O resultado da análise ganhou um painel próprio, com título, resumo, lista numerada e as ações **Baixar MP3**, **Salvar como playlist** (sem baixar), **Adicionar a playlist** (no fim de uma playlist existente, sem baixar) e **Descartar**.
- Clicar na linha não muda a seleção, como nas playlists.
- Um único áudio cria a playlist e a pasta com o próprio nome. Vários áudios usam o nome da página.

## Pasta de destino das playlists

- Playlists novas salvam em `<local>\<nome da playlist>`. O local padrão é a pasta de downloads das Configurações. Sem escolha, no Windows é a própria pasta **Downloads**.
- Cada playlist pode ter um local próprio:
  - **Gerenciar → Pasta de destino**;
  - o ícone de pasta ao lado do nome da playlist aberta;
  - **Salvar em**, na captura.
- Mudar a pasta vale para os próximos arquivos. Os já baixados não são movidos, e a M3U8 aponta para eles por caminho relativo.
- O app nunca grava numa pasta existente que não seja da playlist: usa `Nome (2)`, `Nome (3)` etc.
- Playlists anteriores continuam em `<pasta antiga>\<nome> [id]` até receberem um local.
- Banco: schema 18. A migração não altera faixas, arquivos ou histórico.

## Login de plataforma na captura

- Quando o post pede conta, a janela de login abre sozinha dentro do app, no mesmo modelo da Deezer:
  - janela privada, apagada ao fechar;
  - sessão guardada no cofre do sistema;
  - nenhum cookie do navegador é lido.
- Depois do login, a análise é repetida.
- Vale para **X**, **Instagram**, **TikTok** e **Facebook**. Bluesky e Pinterest funcionam sem conta.
- Os botões de entrar com Google, Facebook, Apple e outros provedores ficam desativados dentro da página de login, inclusive em iframes. A marca da própria plataforma continua ativa.
- **Conexões → Captura de áudio** mostra o estado de cada plataforma, com **Entrar** e **Sair**.
- Sessão recusada pela plataforma é apagada e o login é pedido de novo.
- Motor: yt-dlp 2026.11.23. No Windows, o `curl_cffi` foi corrigido e passou a ser empacotado inteiro.
- Threads não entra: o yt-dlp não tem extrator para ele.

## Status do WhatsApp (só Android)

- Em **Capturar áudio**, o botão **Status do WhatsApp** abre o seletor de pastas do Android já na pasta de status do WhatsApp.
- O app lista os status de vídeo e de áudio, sem as fotos. Você marca os que quer e salva o áudio como playlist "Status do WhatsApp <data e hora>", em MP3, do mais recente para o mais antigo.
- Os arquivos do WhatsApp só são lidos, nunca alterados, e o app não guarda a permissão da pasta.
- Status sem som são pulados e contados na mensagem.
- No Windows o botão não aparece, porque o WhatsApp Desktop não deixa os status em arquivos.

## Validação

- Análise estática sem problemas.
- Regressão Dart offline com todos os arquivos de teste: 322 passaram, 4 opcionais foram ignorados e 2 falharam.
  - As duas falhas eram do `layout_test` no Android a 320 e 390 px: a nova seção **Conexões → Captura de áudio** estourava a largura da janela no celular.
  - Corrigido: em telas estreitas o botão Entrar/Sair fica abaixo do nome da plataforma.
  - Repetidos depois da correção, o `layout_test` e a área de conexões passaram (51 testes).
- Motor Python: 39 testes passaram e 1 foi ignorado. Eles incluem a extração de áudio dos status com vídeos gerados pelo FFmpeg e a detecção de login por plataforma.
- Motor Windows recompilado. A operação nova de extração responde e recusa origem inválida.
- Android, testes nativos no emulador dedicado (`Definitive_API_36`, sem contas reais), todos aprovados com o código da 0.1.110 antes da correção de layout acima, que só muda a disposição de uma linha:
  - Status do WhatsApp (novo): o seletor de pastas do sistema foi conduzido por adb numa pasta de teste com um vídeo com som, um vídeo mudo e uma foto. O app listou os 2 vídeos, extraiu o MP3, pulou o mudo, criou a playlist e apagou a cópia temporária.
  - Captura de áudio, contas, smoke, fila e motor.
  - Duas vezes o Android encerrou o processo de teste logo após instalar, por demora para iniciar com outro emulador ligado. A nova tentativa passou.
- Páginas reais de login do X, Instagram, TikTok e Facebook, abertas sem conta: os botões de outros provedores ficaram desativados e os campos da própria plataforma continuaram ativos. O diagnóstico nativo do Windows (`--check-login-webview`, WebView2 real) passou.
- Não validado:
  - login real em qualquer plataforma, que precisa da conta do usuário;
  - o Status do WhatsApp com o WhatsApp de verdade ou com o WhatsApp Business;
  - ensaios com provedores reais no Android.

## Pacotes

Instalador Windows x64 e APK Android ARM64, com assinatura de teste. As somas SHA-256 estão em `SHA256SUMS.txt`. O APK x86_64 (emuladores) é só para uso interno e não é publicado.
