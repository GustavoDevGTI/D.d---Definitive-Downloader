# Definitive Downloader 0.1.106 (local) — Captura de áudio e pasta de destino

Versão local, sem release ou tag. Muda a página Capturar áudio e a pasta onde cada playlist salva os arquivos.

## Capturar áudio

- A análise mostra o progresso no próprio painel do link, como na importação de playlist (`LinkEntryPanel` com `busy`/`busyLabel`).
- O resultado fica num painel com:
  - título da página e resumo (quantidade, site e duração total);
  - linha **Salvar em** com a pasta final, mais **Alterar pasta** e **Usar padrão**;
  - ações **Baixar MP3**, **Salvar como playlist**, **Adicionar a playlist** e **Descartar selecionados**;
  - lista numerada, com destaque na linha marcada e, por linha, **Abrir página** (só HTTPS) e **Descartar**.
- Como nas playlists (0.1.105), clicar na linha não muda a seleção. Só a caixa da linha e a do cabeçalho mudam.
- **Baixar MP3** cria a playlist com os áudios marcados e inicia o download, como antes.
- **Salvar como playlist** cria a playlist sem baixar e a abre em Coleções.
- **Adicionar a playlist** acrescenta os áudios marcados ao fim de uma playlist existente, escolhida por busca. Nada é baixado nem renumerado. As novas faixas não entram numa fila já em execução.
- Descartar só tira itens da análise. Nada tinha sido salvo.
- Um único áudio cria a playlist e a pasta com o nome dele. Vários áudios usam o nome da página.

## Pasta de destino

- Playlists criadas a partir desta versão salvam em `<local>\<nome da playlist>`.
- O local padrão é a pasta de downloads das Configurações. Sem escolha, no Windows ela passa a ser a própria pasta Downloads (antes era `Downloads\Definitive Downloader`). No Android continua a pasta de mídia do app.
- Cada playlist pode ter um local próprio. A escolha fica em:
  - **Gerenciar → Pasta de destino**, na lista de coleções;
  - o ícone de pasta ao lado do nome da playlist aberta;
  - **Salvar em**, na captura, antes de criar a playlist.
- A janela mostra a pasta final e tem **Abrir pasta**. Mudar a pasta vale para os próximos arquivos. Os já baixados continuam onde estão, e a M3U8 aponta para eles por caminho relativo.
- A pasta é reservada no primeiro arquivo (`output_folder`) e não muda se a playlist for renomeada. Se já existir uma pasta com esse nome que não é desta playlist, o app usa `Nome (2)`, `Nome (3)` etc. Ele nunca mistura arquivos nem a `playlist.m3u8` numa pasta alheia ou de outra playlist.
- Playlists anteriores (marcadas `legacy_folder` na migração) continuam em `<pasta antiga>\<nome> [id]`, seguindo as Configurações como antes, até receberem um local próprio. Nenhum arquivo foi movido.
- Mudar a pasta fica bloqueado durante downloads e importações.
- A substituição de duplicatas (0.1.47) aceita arquivos na pasta reservada da playlist, além da pasta antiga `<nome> [id]`. Arquivos que ficaram numa pasta anterior à troca não são apagados por ela. A revisão recusa e informa.

## Banco

Schema 18: `collections.output_root` (local escolhido, vazio usa o padrão), `output_folder` (pasta reservada) e `legacy_folder` (1 para playlists existentes na migração). A migração não altera faixas, arquivos ou histórico.

## Validação

- `flutter analyze --no-pub`: sem problemas.
- Essenciais e áreas capture, storage, local_audio, collections, downloads, mobile, ui_collections e ui_common: 184 testes aprovados.
- Regressão Dart offline completa (60 arquivos): 312 aprovados e 4 opcionais ignorados.
  - Os testes de migração ganharam `removePlaylistDestinationSchema` para reconstruir o schema 17.
- Novos testes:
  - `collection_destinations_test`: pasta antiga preservada após a migração, nome numerado quando a pasta existe ou pertence a outra playlist, pasta estável ao renomear, local próprio e volta ao padrão, M3U8 com caminho relativo;
  - `audio_capture_test`: pasta com o nome do áudio único, descartar, salvar como playlist com a pasta escolhida sem baixar, adicionar ao fim de uma playlist existente;
  - layout da captura em 320 e 1360 px, com linha que não altera a seleção.
- Na primeira rodada, o teste de 320 px achou um estouro na linha "1 de 2 selecionados", já corrigido. O mesmo teste falhou uma vez por tempo de espera sob carga e passou nas repetições.
- Android: o seletor de local usa o mesmo `chooseOutput` já validado em Configurações. A pasta da playlist fica um nível abaixo da raiz escolhida, como o adaptador SAF exige. Não houve ensaio nativo no emulador nesta versão.
- Não houve download real de provedor nem análise de página real.
