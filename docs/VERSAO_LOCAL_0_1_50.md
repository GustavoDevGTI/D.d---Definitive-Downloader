# 0.1.50+51 — motor musical Android

Entrega local Android, sem release/tag. Windows instalado permanece na 0.1.48. Continua a execução da [paridade completa](ANDROID_PARIDADE_CHECKLIST.md); esta entrega conclui o primeiro bloco de fontes, sem declarar todas as funções mobile concluídas.

## Implementação

- Motor Android próprio por MethodChannel, CPython/FFmpeg/QuickJS Android ABI e núcleo dos provedores compartilhado. Nenhum worker EXE/artefato Windows ou conta da instalação desktop foi copiado.
- Health executa codec MP3 e vetor do backend portátil de blocos; capacidade só é habilitada após essa validação. SoundCloud, Deezer, YouTube Music e YouTube usam os adaptadores/políticas existentes, preservando identidade, duração e aprovação por versão.
- Processo por operação com argumentos estruturados, handshake PID/grupo/nonce antes de permitir filhos, pausa por protocolo e cancelamento só do grupo próprio. Credenciais exclusivamente no pipe/cofre. Limites de eventos, tamanho, tempo ativo e diretórios temporários. Não usar execução/cancelamento por shell do SDK upstream.
- Dependências puras travadas por arquivo/hash; EJS acompanha o APK e QuickJS é apontado explicitamente. Build recusa divergência requirements/lock, wheel nativo/Windows, expansão excessiva e ABI sem runtime completo.
- Testes nativos usam pacote `.integration`; runner valida APK prévio do cache, impede limpeza do app principal e conserva dados. A execução final do aplicativo usa pacote normal, sem sufixo.

Arquitetura, fontes primárias e comandos: [motor compartilhado](ANDROID_MOTOR_COMPARTILHADO.md).

## Validação proporcional

- Essencial + adaptador Android/protocolo: 26 testes passaram. Análise Flutter sem problemas. Não executada a regressão completa.
- Runner isolado executado com health nativo: CPython 3.12.11, codec e vetor aprovados, pacote `.integration` conferido e sem desinstalação automática.
- Vetor portátil e fragmentação comparados ao backend Windows: 2 testes passaram; 18 contratos focados de política, SoundCloud, pausa e progresso passaram no worker, sem contas.
- Buscas públicas reais no emulador Android 16/API 36 x86-64: Deezer 2 candidatas, YouTube Music 8 e SoundCloud 8.
- SoundCloud real sem conta: duas ocorrências, arquivos MP3 distintos com capa/tags e duração nativa, histórico SQLite/M3U8, pausa após bytes recebidos e cancelamento durante processamento. 13 eventos de progresso; zero grupos cancelados restantes; arquivos concluídos preservados.
- YouTube Music real sem conta: Sick Sense/LEAP, ATV, MP3 completo de 4.801.742 bytes; capa/título, decodificação e duração nativa verificados. Uma comparação de aliases de caminho do teste foi corrigida; somente esse caso foi repetido e passou.

Não comprovados nesta rodada: conta/áudio real Deezer, fonte YouTube manual/videoclipe em ensaio próprio, fila/UI completa com recuperação/duplicatas, importações públicas de todas as playlists, callback/autenticação Spotify Android, SAF público/SD, compartilhamento recebido, serviços/notificações/segundo plano e aparelho físico. Continuam no checklist, sem reduzir o escopo. A base nativa não dá suporte universal a todos os catálogos/contas.

## Pacote

APK de teste debug, ARM64/x86-64, package `br.com.definitivedownloader.app`, versionCode 51. Destinos de mídia continuam pertencentes ao app; desinstalar remove seus dados. Assinatura de produção e distribuição Play não fazem parte desta entrega local.

Pacote final compilado e assinatura v2 verificada; mínimo API 24/target 36. Build conferiu Flutter/SQLite/Python/FFmpeg/QuickJS e pacotes de dados nas duas ABIs, com bundle portável `8886dc20e5c1fc07cd8b155dd0e1eae3c44cbcad3bd7db70a6a8812ca7226028`. SHA-256 do APK: `0372b2bb94dcf2a97375294b07ce3dd2437ff0baa261eef8de37f18668bc4dc0`. Cópia em Downloads conferida pelo mesmo hash. Evidências/arquivos temporários e contas ficam fora do Git.
