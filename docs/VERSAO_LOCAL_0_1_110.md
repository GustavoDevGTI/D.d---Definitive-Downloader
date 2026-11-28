# Definitive Downloader 0.1.110 (interna) — Status Saver no Android

Versão só interna, sem release ou tag. Pedido do usuário: Status Saver apenas na versão Android.

## O que faz

- Em **Músicas → Capturar áudio**, só no Android, o botão **Status do WhatsApp** abre o seletor de pastas do sistema já na pasta de status do WhatsApp (`Android/media/com.whatsapp/WhatsApp/Media/.Statuses`). Se a pessoa escolher a pasta `WhatsApp/Media`, o app usa a `.Statuses` dentro dela.
- O app copia para a área temporária dele os status de vídeo (`mp4`, `3gp`, `mkv`, `webm`) e de áudio (`opus`, `ogg`, `m4a`, `aac`, `mp3`):
  - fotos ficam de fora;
  - limites: 200 status, 200 MB por status e 2 GB no total;
  - os arquivos do WhatsApp só são lidos, nunca alterados;
  - a permissão da pasta não é guardada.
- Os status aparecem num painel no padrão do resultado da captura:
  - título "Status 27/11 14:30", tipo e tamanho;
  - seleção pela caixa;
  - **Salvar áudio como playlist** e **Descartar**.
- Ao salvar, o motor extrai o áudio de cada status em MP3 (operação `extractAudio`, com o mesmo FFmpeg e a mesma validação completa do download, e tags de título e álbum "Status do WhatsApp"). A playlist "Status do WhatsApp 27-11-2026 14h30" é criada pela importação local já existente: cópia numerada na pasta da playlist, faixas concluídas e locais, na ordem mostrada (mais recente primeiro).
- Status sem som são ignorados e contados na mensagem final. A cópia temporária é apagada ao salvar, ao descartar ou ao sair da página.
- Windows: o botão não aparece (`supportsStatusSaver` falso). O WhatsApp Desktop não guarda status em arquivos acessíveis.

## Segurança

- O nativo só aceita `extractAudio` com:
  - origem dentro de `cache/imports/whatsapp-statuses`, até 200 MB;
  - destino numa pasta vazia do próprio app.
- O motor confere também a extensão, o tamanho, a pasta vazia e o título.
- A limpeza só remove pastas de lote (nome UUID) dentro dessa raiz.

## Validação até aqui

- Motor Python: 39 testes aprovados e 1 ignorado. `test_status_audio` usa vídeos gerados pelo FFmpeg: com som vira MP3 com tags e duração correta; mudo dá mensagem clara; entradas inválidas são recusadas.
- Dart:
  - análise sem problemas;
  - essenciais e áreas capture, mobile, local_audio e connections: 93 aprovados e 1 ignorado.
  - Na primeira rodada falhou `collection_composition_layout_test` por tempo sob carga; ele passou duas vezes sozinho.
- `status_saver_test` (novo): títulos e nome da playlist; lista sem a foto; extração dos escolhidos com o mudo ignorado; playlist na ordem com faixas locais concluídas; limpeza da cópia; seleção vazia; descarte; seletor cancelado; botão ausente no Windows.
- APKs 0.1.110 gerados por `tools/build_android.ps1` (o Kotlin novo compilou):
  - `Definitive-Downloader-0.1.110-Android-arm64-v8a-teste.apk`, SHA-256 `a846f572ed2daec4f0d7781b8fbda81f90533c111da6c13e9d8fb9826552b0e1`;
  - `Definitive-Downloader-0.1.110-Android-x86_64-teste.apk` (interno), SHA-256 `3c7f8ea90194b05e6789cc1aa7c2a89154e8369ef0124224fcbd207102a6381f`.
- Testes nativos no `Definitive_API_36` (emulator-5560), todos aprovados:
  - `android_status_saver` (novo): a pasta `.Statuses` de teste tinha um vídeo com som, um vídeo mudo e uma foto. O seletor SAF real foi conduzido por adb. O app listou 2 status sem a foto, extraiu o MP3 pelo motor Android, ignorou o mudo, criou a playlist com 1 faixa local concluída e apagou a cópia temporária;
  - `android_audio_capture`, `android_account_flow`, `android_smoke`, `android_queue` (3) e `android_music_engine` (1 ignorado).
- Ambiente: o emulador de outro projeto ficou ligado ao mesmo tempo. Duas vezes o Android encerrou o processo de teste logo após a instalação ("failed to attach / start timeout"), e o Flutter ficou esperando. A nova tentativa do mesmo teste passou; não houve falha do app.

## Limitações

- Não foi testado com WhatsApp real nem com WhatsApp Business (`com.whatsapp.w4b`), que pode ser escolhido manualmente no seletor.
- Sem release ou tag (versão interna).
