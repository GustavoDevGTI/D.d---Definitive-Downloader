# Download musical integrado — 28/10/2026

## Estado comprovado

O D.d Windows agora possui busca e download musical integrados, com adaptadores próprios para Deezer e YouTube Music. A interface oferece **Buscar músicas**, revisão por ocorrência e **Baixar selecionadas**. O login Spotify continua responsável pela importação de metadados; não é a fonte do áudio.

**Rodada nativa concluída:** a coleção de produção **Teste** terminou com dez arquivos: **sete da Deezer e três do YouTube Music**. A pessoa conectou a própria conta Deezer pelo campo local e informou que o plano é gratuito. O app restaurou essa conexão após um reinício, sem nova entrada de ARL. Foram corrigidos a inicialização pela UNC, a extração do JSON da página Deezer e o processamento dos blocos de áudio antes da conclusão.

Após o pedido de identificação, os dez arquivos receberam `[Deezer]` ou `[YouTube Music]` no nome, e a M3U8 passou a exibir a mesma origem em cada entrada. O banco foi atualizado para os novos caminhos e os hashes dos MP3s permaneceram iguais: seus conteúdos não foram modificados. A coluna **Origem do áudio** e os downloads futuros usam o mesmo identificador. O relatório anterior registra os caminhos originais, anteriores à renomeação.

Os três primeiros arquivos usaram YouTube Music durante o diagnóstico, antes das correções Deezer. Foram preservados como concluídos; não foram tentados novamente na Deezer corrigida. Portanto, o resultado **não significa que apenas sete dessas músicas estejam disponíveis na Deezer**. As sete ocorrências restantes, posições 4 a 10, vieram diretamente dela. A conta gratuita funcionou para esses casos; não extrapolar para todo catálogo, região ou conta.

A [verificação independente nativa](evidencias/music-native-deezer-youtube-live.json) confirmou duração, uma capa por arquivo, tag da origem real, decodificação integral FFmpeg sem erros, hash e sequência M3U8. Os três identificadores YouTube Music foram novamente consultados e confirmados como ATV, sem conteúdo ao vivo. O SQLite v5 passou em `quick_check`, preservando as coleções.

```text
C:\Users\gustavoborges\Downloads\Definitive Downloader\Teste [2]\playlist.m3u8
```

Esta rodada operou pela interface Windows sobre os metadados Spotify importados anteriormente. Não fez nova importação Spotify nem criou uma playlist em outra conta. Renovação após expiração, outras playlists e mobile ainda exigem validação própria.

### Ensaio anterior pelo runner Flutter

| Caminho | Resultado observado |
| --- | --- |
| Spotify → metadados | Importação autenticada anterior da playlist Teste, com 10 faixas, preservada no banco do app. |
| YouTube Music → MP3 | 10/10 arquivos reais obtidos pelo fluxo de produção via runner Flutter, em banco separado. |
| Tipo da fonte | Todos os dez identificadores reconferidos no catálogo como `MUSIC_VIDEO_TYPE_ATV`, sem conteúdo ao vivo. |
| Arquivos | Dez MP3s, cada um com uma capa APIC, duração conferida e decodificação integral FFmpeg sem erro. |
| Playlist local | M3U8 com dez caminhos existentes, posições 1 a 10 na ordem de entrada. |
| Deezer autenticada | Não utilizada neste ensaio anterior; validada posteriormente na rodada nativa descrita acima. |
| Interface nativa | Não utilizada neste ensaio anterior; a execução posterior pela UI concluiu os dez arquivos. |
| Layout | Telas de coleção e conexões renderizadas com fixtures e conferidas visualmente em 900 e 1360 px; controles acessíveis, sem overflow observado. |
| Mobile | Contratos Dart compartilháveis; runtime musical mobile ainda não implementado nem validado. |

Esse ensaio anterior não fez uma nova importação Spotify: usou os metadados da importação autenticada anterior. Não leu sessões salvas e não usou uma conta Google ou Deezer. Ele, isoladamente, não demonstra transferência remota entre contas nem download combinado de dois provedores.

## Evidências e arquivos

- [Verificação independente por arquivo](evidencias/music-audio-only-live.json): URLs reais, tipo, duração, hash SHA-256, capa e código de decodificação.
- [Rodada nativa com os dois provedores](evidencias/music-native-deezer-youtube-live.json): dez arquivos na coleção de produção, sete Deezer e três YouTube Music, com tentativas registradas sem credenciais.
- [Análise estática](evidencias/music-integration-analyze.log), [44 testes Flutter](evidencias/music-integration-tests.log), [build Windows](evidencias/music-integration-build.log) e [políticas do worker](evidencias/music-worker-policy.log).
- [Primeira rodada real](evidencias/music-live-first.log) e [conclusão da rodada](evidencias/music-live-resume.log).
- [Layout em 900 px](images/music-library-900.png) e conexões em [900](images/music-connections-900.png) / [1360 px](images/music-connections-1360.png): fixtures, não evidência de conta conectada.
- Após acrescentar o registro por fonte: [análise](evidencias/music-attempts-analyze.log), [44 testes Flutter](evidencias/music-attempts-tests.log), [build nativo](evidencias/music-attempts-build.log) e [cinco testes do worker](evidencias/music-worker-policy.log).

Pasta local dos resultados:

```text
C:\Users\gustavoborges\Downloads\Definitive Downloader\Testes\dd-music-trial-6e32381d\Teste - faixas de áudio [1]
```

O banco `trial.sqlite3` e `trial-report.json` ficam no diretório pai. O JSON é uma evidência limitada de dez itens, não o armazenamento operacional de playlists. O banco de produção e a coleção original permanecem separados do ensaio.

A primeira rodada preparou nove faixas e reteve **Exit Music (For A Film)** por ambiguidade entre edições. O matching passou a preferir uma única correspondência do álbum pedido entre candidatos já aprovados nas demais regras. Isso permitiu selecionar **OK Computer**. Três testes cobrem o desempate e ambiguidades restantes; a retomada preservou os nove arquivos concluídos e finalizou o décimo.

## Política contra videoclipes

1. A busca YouTube Music usa o filtro `songs`; exige álbum e tipo `MUSIC_VIDEO_TYPE_ATV`.
2. A escolha automática e manual bloqueia tipos diferentes ou ausentes. Títulos de videoclipe também são recusados.
3. Antes de obter áudio, o worker consulta novamente a identidade, o tipo, a disponibilidade, o estado ao vivo e a duração.
4. O downloader recebe o identificador exato em `music.youtube.com`, sem busca genérica ou fallback para vídeo.
5. A gravação completa passa pela conferência de duração e decodificação. Não há corte para mascarar uma versão errada.

ATV é o critério técnico observado no catálogo, não uma análise perceptual de silêncio/ruídos de cada master. Não foi feita escuta humana integral das dez músicas. MP3 é transcodificado sem alegação de ganho de qualidade; tags da fonte real ficam separadas dos metadados pedidos no Spotify. Todos os colaboradores e a classificação explícita não foram auditados manualmente em cada arquivo.

## Arquitetura

- Flutter/Dart mantém domínio, matching, controle, SQLite e apresentação em módulos próprios.
- `MusicEngine` define o contrato; `WindowsMusicEngine` executa um worker próprio por operação, sem shell, com timeout, limites e cancelamento do processo iniciado.
- `runtime/music_worker` separa catálogo YouTube Music, conta Deezer, transporte, arquivos e validação. O pacote Windows inclui Python e FFmpeg.
- Schema SQLite v4 acrescenta candidatos relacionais por ocorrência e metadados reais da fonte; v5 acrescenta o último resultado por provedor/ocorrência em `music_source_attempts`. A migração nativa preservou as duas coleções e as dez faixas importadas; `quick_check` retornou `ok`.
- Sessão Deezer entra apenas no campo mascarado local; é validada e guardada no cofre. Cookie fica restrito a `www.deezer.com`; transporte de mídia é separado. Não há credenciais em SQLite, parâmetros de linha de comando ou evidências.
- Uma falha Deezer só permite alternativa YouTube Music previamente aprovada no mesmo matching. A fonte efetivamente utilizada permanece identificada; o último erro sanitizado por fonte fica registrado antes do fallback, sem requisição, sessão ou URLs assinadas. A posição 1 antecedeu esse registro; posições 2 e 3 documentam as falhas dos adaptadores anteriores, não uma recusa comprovada da conta.
- Arquivos são recebidos em staging próprio, conferidos, etiquetados e publicados sem sobrescrever arquivos alheios. Progresso de rede não significa conclusão.

Não foi incorporado código C2/JDownloader nem os motores spotDL/Zotify/librespot. A análise do C2 serviu para entender a capacidade e os problemas que precisavam ser evitados.

## Build e reprodução

Flutter 3.47.8 / Dart 3.13.7, build Windows release. Dependências Python travadas em `runtime/music_worker/requirements.txt`, empacotadas com PyInstaller 6.16.0. Dependências Flutter permanecem em `pubspec.lock`.

`tools/build_windows.ps1` prepara o build local e publica o app. `tools/build_music_engine.ps1 -Python <python-do-build> -WorkspaceRoot <workspace>` publica `dist/DefinitiveDownloader/music_engine`. Em workspace UNC, execute os scripts a partir de cópia local aprovada pela política atual da máquina; não altere a política de execução. O segundo script aceita explicitamente o workspace de origem. Não use um arquivo `.bat` do SDK tendo uma UNC como diretório atual.

O Python usado no build possui uma política adicional de certificados em `codex-rejected-cas.pem`. O empacotamento preserva esse arquivo público junto de `ssl.py`; a validação TLS permanece ativa. Sua ausência causou falha de transporte na primeira tentativa do pacote e foi corrigida antes do ensaio final.

`tools/music_trial_test.dart` é um ensaio real explícito fora da suíte padrão. Recebe por variáveis `DD_LIVE_WORKER`, `DD_LIVE_DATABASE` e `DD_LIVE_OUTPUT`; `DD_LIVE_RESUME_DIR` permite retomar o banco isolado. Faz chamadas externas e gera arquivos. Os testes comuns usam fixtures e não comprovam acesso a provedores.

## Diagnóstico e correções da rodada nativa

### Correção da inicialização pela rede

O usuário informou **“O motor musical não concluiu a operação”** ao tentar conectar a Deezer. O problema foi reproduzido sem conta: o app Flutter nativo pela UNC iniciou o worker, que encerrou com código 1, zero bytes de resposta e `ImportError` ao carregar `_socket` durante um hook do PyInstaller. O mesmo teste nativo no pacote local passou: health válido e rejeição explícita da sessão fictícia. O teste pelo runner Flutter com caminho UNC explícito também passou; portanto, o primeiro ensaio de download pelo runner não cobria essa falha da execução nativa pela rede.

`INICIAR.cmd` agora atualiza e abre a cópia completa em `%LOCALAPPDATA%\DefinitiveDownloader\app`, sem alterar o cofre ou o banco. A sincronização não remove arquivos. O cliente passa a informar código de saída e quantidade de bytes quando o worker não responde. O modo explícito `--check-music-engine` testa somente health e uma sessão fictícia; não lê contas nem cofre. Se health falhar, captura stderr somente de uma segunda chamada health, sem credenciais.

Evidências: [falha nativa UNC](evidencias/music-unc-launch-failure.json), [sucesso do pacote local](evidencias/music-local-launch-check.json) e [pacote aberto pelo inicializador](evidencias/music-launcher-package-check.json). Esses diagnósticos comprovam somente comunicação e rejeição sintética. A autenticação real foi concluída depois pelo usuário; a rodada de mídia está em evidência própria.

### Leitura de estado e blocos de áudio

A tentativa da posição 2 registrou ausência de dados de reprodução. Uma [consulta pública sem credenciais](evidencias/deezer-public-parser.json) demonstrou que a atribuição de estado existia, mas a expressão exigia um fechamento de script que a página não usava. O novo leitor usa `JSONDecoder.raw_decode` para extrair um objeto, aceitando scripts sem ponto e vírgula ou com outras atribuições depois, sem executar JavaScript. Testes incluem delimitadores dentro de strings e entradas inválidas.

A posição 3 ainda foi rejeitada por duração após a primeira correção. A revisão encontrou um valor incorreto no cálculo dos blocos do adaptador anterior. A rotina foi isolada em `deezer_audio.py`, corrigida e testada com vetor conhecido, múltiplos blocos protegidos e fragmentações de transporte de 1 a 65536 bytes. A validação de duração não foi relaxada; seu erro agora informa os milissegundos recebidos e esperados.

A posição 4 foi o primeiro sucesso Deezer: 101,642 s recebidos para 101 s de catálogo, uma capa APIC, tag `https://www.deezer.com/track/3616701872` e decodificação integral sem erro. As posições 5 a 10 também concluíram pela Deezer. Nenhum arquivo truncado das tentativas anteriores foi publicado como faixa completa.

### Próximas validações

Atualização de 29/10/2026: na versão 0.1.5, a playlist Teste foi importada novamente pela UI e concluiu dez MP3s Deezer, com capa, duração e decodificação verificadas e M3U8 ordenada. “Exit Signs” foi aceita pelo usuário com ressalva de classificação explícita/limpa divergente entre catálogos. O motor YouTube Music ATV também concluiu um arquivo real em ensaio complementar direto, sem alterar a coleção. Controles, correção de cancelamento e limites estão em [RELEASE_0_1_5.md](RELEASE_0_1_5.md); evidências reais são distintas dos testes offline.

Conferir outras playlists e ocorrências repetidas reais, sessões expiradas e indisponibilidade por faixa, com a fonte efetiva sempre identificada. Uma conta conectada e sete sucessos não comprovam disponibilidade universal. Não pedir senha/ARL no chat ou consultar cookies existentes.

Google OAuth para criar playlists, transferência remota, renovação real de sessão e implementação mobile continuam etapas distintas.
