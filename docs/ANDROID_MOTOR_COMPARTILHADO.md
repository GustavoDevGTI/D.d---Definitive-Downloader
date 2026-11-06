# Motor musical Android: fronteira de execução

Implementado após o checkpoint 0.1.49, com validações por provedor em andamento. Objetivo: portar as operações já existentes de Deezer, YouTube Music, YouTube e SoundCloud, mantendo as regras e a validação do produto.

- A biblioteca Android `youtubedl-android` 0.18.1 fornece distribuições Android de CPython/FFmpeg/QuickJS. Usar apenas sua inicialização de pacotes. Não usar sua execução/cancelamento: a revisão do upstream encontrou cancelamento de descendentes por shell, incompatível com as regras D.d.
- O app inicia seu próprio bootstrap com ProcessBuilder/argumentos separados, sem shell, binário no diretório nativo do APK e dados/código Python em pasta privada. O bootstrap cria grupo próprio e confirma PID/nonce no pipe privado antes de iniciar fontes. Cancelamento usa somente esse trabalho e seus descendentes, sem varrer outros processos.
- Protocolo JSON por operação, limites, progresso e controle de pausa continuam iguais. Credenciais seguem exclusivamente no corpo de entrada do processo e no cofre, sem argumentos, logs ou arquivos. Eventos de resultado/erro são verificados; stderr não é mostrado cru.
- O núcleo de provedores Python é compartilhado como código; as dependências Android são puras Python e travadas por hash. Não usar wheels Windows, EXE ou diretórios de contas Windows. Blowfish dos blocos legados recebe backend portátil testado por vetor conhecido, com chave expandida uma vez.
- QuickJS e `yt-dlp-ejs` fixado em 0.8.0 acompanham o APK; o app não baixa scripts de solver em runtime. O build compara requirements/lock e verifica hashes, formato portátil e limites de expansão. As licenças dos pacotes acompanham o bundle. [Requisitos EJS do yt-dlp](https://github.com/yt-dlp/yt-dlp/wiki/EJS).
- Runtime e bundle precisam passar health/execução Android antes de anunciar disponibilidade. Health não comprova conta, catálogo ou todas as fontes. Depois, ensaios por fonte e fila comprovam download completo, capa/tags, M3U8, pausa/cancelamento e histórico.

Referência primária: [SDK Android e sua versão fixada](https://github.com/yausername/youtubedl-android/tree/0.18.1). Não aplicar a sugestão antiga de acesso amplo/armazenamento legado: as mídias continuam em staging próprio e exportação usa a integração de documentos do app.

## Ensaios próprios

Emulador dedicado Android 16/API 36 x86-64, sem contas/biblioteca Windows. SoundCloud: faixa pública `the-concept-band/the-concept-d-d-dance`, ID 30510138; duas cópias MP3, título/capa ID3, duração conferida pelo leitor Android, histórico SQLite e duas entradas M3U8. Pausa observada após bytes recebidos; cancelamento solicitado no estágio de conferência/processamento; grupo do trabalho encerrado e cópias concluídas preservadas. Resultado: 2 arquivos, 13 eventos de progresso, zero grupos cancelados ainda ativos. Não é prova de todas as contas/catálogos ou de segundo plano.

Buscas reais Android: Deezer 2 candidatas, YouTube Music 8 e SoundCloud 8. Resultados públicos são metadados; não comprovam automaticamente obtenção.

YouTube Music: `Sick Sense`, LEAP, áudio ATV; MP3 de 4.801.742 bytes, capa/título ID3, decodificação integral pelo FFmpeg e duração conferida pelo leitor Android. Sem conta. Primeira execução do teste recebeu o áudio, mas falhou ao comparar literalmente os aliases `/data/user/0` e `/data/data`; a asserção passou a comparar destinos reais. Repetição somente desse caso passou. Não houve corte de duração nem substituição da gravação.

Reproduzir ensaios focados no estágio preparado, em dispositivo de teste:

```powershell
./tools/test_android.ps1 -TestFile integration_test/android_music_engine_test.dart -LiveSources
./tools/test_android.ps1 -TestFile integration_test/android_provider_test.dart -LiveSources
```

O runner exige estágio Android identificado, prepara/verifica o pacote `.integration` no cache de build e passa `DD_ANDROID_INTEGRATION=true` e `--no-uninstall`. A verificação prévia é necessária porque o Flutter 3.47.8 conserva o identificador do APK anterior para o encerramento do teste, mesmo que o build altere o pacote; isso foi encontrado na primeira troca de variante. Nenhum teste deve tentar desinstalar o pacote principal. O define conserva o sufixo mesmo quando Flutter gera listener intermediário fora de `integration_test/`. Pacote independente verificado por manifesto/ADB; não publicar esse APK como app normal. Os ensaios usam diretórios temporários próprios e apagam apenas esses dados. Não entram no perfil essencial/offline nem devem ser repetidos a cada ajuste visual.
