# Definitive Downloader 0.1.5

Revisão de 29/10/2026: continuar o ensaio solicitado com playlist Spotify, preferência Deezer e alternativa YouTube Music ATV, e concluir os controles de Músicas → Downloads. Versão Flutter `0.1.5+6`; o instalador deriva sua versão de `pubspec.yaml`.

## Comportamento

- “Baixar selecionadas” na coleção inicia a seleção e abre Downloads. A fila consulta ocorrências reais do SQLite, com filtros e paginação de 40 registros.
- Comandos com ícone, rótulo, ajuda e espaçamento em painel. Execução fica na primeira linha; prioridade e arquivos na segunda, com quebra e rolagem no mobile. Nenhum dado da biblioteca é limpo ao atualizar.
- Iniciar usa somente a seleção habilitada; Tentar novamente usa somente falhas selecionadas. Uma falha não é repetida indefinidamente na mesma execução.
- Pausar limita a recepção atual a 10 KiB/s e impede novas transferências. É possível retomar durante a transferência; caso ela termine pausada, a execução encerra e as próximas continuam disponíveis para iniciar. Parar cancela somente a operação iniciada pelo app, preservando os arquivos concluídos; a próxima tentativa do incompleto reinicia do começo.
- Prioridade varia de −4 a +4 e altera a próxima escolha, inclusive durante execução. A posição das ocorrências e a ordem da M3U8 permanecem originais. O valor aparece na ajuda do nome da faixa.
- Abrir pasta abre a localização do arquivo selecionado e informa indisponibilidade. Remover oculta os selecionados da fila; não remove o ativo, a coleção, a mídia ou o histórico de Arquivos. Um novo vínculo de fonte torna a ocorrência visível novamente.
- Schema v7 acrescenta `queue_priority`, `queue_run` e índice da fila, preservando fontes manuais, histórico e ocorrências. Backup local anterior à migração em `%LOCALAPPDATA%/DefinitiveDownloaderDev/backups/before-downloads-015-20261029-142712.sqlite3`.
- O worker mantém controles por stdin, sem arquivos de sessão ou parâmetros sensíveis. A leitura usa o pipe bruto para evitar bloqueio de finalização do Python com uma thread aguardando controles. Falhas de escrita no pipe de um processo já encerrado não escapam ao temporizador Flutter.

Referência funcional consultada: [modo pausa](https://support.jdownloader.org/es/base-de-datos/article/speed-limit-pause-mode) e [prioridade e pasta](https://jdownloader.org/knowledge/wiki/gui/downloadlink-context-menu) do JDownloader. A identidade visual do D.d foi mantida.

## Verificações e limites

- `dart format --output=none --set-exit-if-changed lib test`: 67 arquivos, sem diferenças.
- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub`: 66 testes aprovados. Incluem migrações v2/v5/v6, ordem e repetições, seleção entre coleções, cancelamento, pausa, prioridade alterada durante execução, preservação da M3U8, remoção sem apagar histórico e retorno da última página removida. O teste adicional reproduz erro local de limpeza após parar, sem registrá-lo como falha do provedor.
- Worker: oito testes offline aprovados, incluindo o limite de pausa, retomada e aceitação somente de comandos booleanos. Health do pacote local retornou sucesso; requisição sintética de download inválida encerrou com erro sanitizado e sem falha de finalização. Esses diagnósticos não são login ou download real.
- Layout testado em 1360×820, 900×820, 900×600, 390×820 e 320×820 com texto 1,3× no último. Revisão visual das capturas desktop/mobile em `%LOCALAPPDATA%/DefinitiveDownloaderDev/downloads-015-captures`; são fixtures isoladas.
- `flutter build windows --release --no-pub`: pacote final Windows `0.1.5+6` compilado. Instalador Inno Setup `0.1.5` gerado em `%LOCALAPPDATA%/DefinitiveDownloaderDev/release-015-final`, sem sobrescrever releases anteriores. Instalação limpa não ensaiada; instalador sem assinatura digital.
- App final iniciado por `INICIAR.cmd`. Hashes do executável, `data/app.so` e worker iguais em `dist`, no pacote final da release e na cópia local em execução.
- Banco real após a rodada: `quick_check=ok`, schema 7, dez ocorrências, dez concluídos, dez tentativas Deezer bem-sucedidas e dez registros de histórico. “Abrir pasta” abriu o Explorador em `Teste [1]`. Remoção da fila e Tentar novamente foram verificados em fixtures; nenhum download real foi removido para exercitar comandos.

## Ensaio real pela interface Windows

Playlist Spotify `4PYxm8yonIPl6XxizOPYb1`, coleção **Teste**: importação autenticada integral de dez ocorrências. Nove correspondências automáticas Deezer; “Exit Signs” exigiu revisão porque o Spotify a marca explícita e a Deezer a marca limpa, embora o ISRC `USA2P2328852`, artista e duração coincidam. O usuário autorizou expressamente aceitar a versão Deezer com essa ressalva. O alerta não foi removido das regras de matching.

Dez MP3s concluídos pela Deezer na pasta `C:/Users/gustavoborges/Downloads/Definitive Downloader/Teste [1]`. Todos têm uma capa APIC, tags de título/artista/álbum e fonte, duração a até dois segundos do catálogo e decodificação integral FFmpeg sem erro. M3U8 com dez entradas em ordem original e indicação Deezer; hashes SHA-256 individuais em [evidência dos arquivos](evidencias/downloads-015-real-files.json). A classificação explícita/limpa da posição 6 permanece uma divergência autorizada de metadados; não foi feita comparação das letras.

A UI abriu Downloads ao iniciar pela coleção. Pausa e retomada foram acionadas durante uma transferência real. A parada preservou o primeiro concluído. O primeiro diagnóstico revelou que uma falha ao remover staging podia encobrir cancelamento e escolher YouTube Music; isso não era evidência de indisponibilidade Deezer. A correção impede esse mascaramento e confere cancelamento antes de registrar falha ou escolher alternativa. A fonte Deezer foi restaurada pela UI e a parada repetida no pacote final: posições 1 e 2 concluídas, posição 3 pronta e ainda Deezer, nenhuma falha nova de provedor. Na conclusão, todas as dez tentativas Deezer tiveram sucesso. Prioridade + e − foram acionadas e a fila voltou à ordem inicial. Recomeçar não baixou novamente os arquivos concluídos. A última execução informou oito novos arquivos, somados aos dois já concluídos.

O fluxo final não precisou de fallback. Para validar também o motor YouTube Music atualizado, foi feito um ensaio complementar real de **Sick Sense**, com candidato ATV compatível em título/artista/duração e classificação explícita. Gerou MP3 de 212036 ms com capa e decodificação completa. Esse ensaio chamou o worker diretamente, em pasta de desenvolvimento, sem mudar a fonte da coleção nem ser apresentado como clique de download na UI. [Evidência YouTube Music](evidencias/downloads-015-youtube-music-real.json).

As credenciais foram restauradas pelo próprio aplicativo a partir do cofre. Nenhum cookie existente, token ou sessão foi inspecionado, solicitado novamente ou gravado nas evidências. Esses resultados abrangem a conta, as faixas e o ambiente Windows testados; não comprovam todo catálogo, sessão expirada ou obtenção mobile.

Logs `docs/evidencias/downloads-015-*`. Não houve publicação remota. Tag `v0.1.5` pendente: a pasta fornecida não contém metadados Git nem vínculo remoto verificável. Nenhum repositório novo ou remoto foi inventado.

Os controles e o domínio Dart são compartilhados e o layout mobile foi testado em widgets. Não há motor nativo mobile, APK/IPA nem ensaio real em celular nesta entrega; o piloto Windows continua parcial no escopo do produto. Métricas de rede, captura geral, vídeos/fotos, formatos adicionais e transferência entre contas permanecem indisponíveis.
