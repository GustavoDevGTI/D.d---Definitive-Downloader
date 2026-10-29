# Primeira versão desktop — Definitive Downloader 0.1

Entrega de 27/10/2026. Nome definido pelo usuário: **Definitive Downloader**, abreviado **D.d**. Flutter/Dart foi mantido conforme decisão explícita. O foco atual é Windows; mobile continua previsto na arquitetura e ainda não foi entregue.

A renomeação migra a biblioteca anterior para a nova identidade sem substituir uma biblioteca já existente. O banco anterior é preservado e os caminhos de arquivos concluídos continuam válidos. Referências antigas em logs de evidência são históricas; identificadores de compatibilidade ficam restritos à migração.

Revisão da renomeação: análise estática sem problemas, 22 testes aprovados e novo executável compilado. A abertura da versão D.d migrou as seis ocorrências existentes, preservando seleção, ordem, estado concluído e caminhos dos arquivos. O pacote anterior foi arquivado em `dist/previous-build`; o lançador usa somente `dist/DefinitiveDownloader/definitive_downloader.exe`. Logs em `evidencias/renomeacao-*.log`.

## Uso

Abra [INICIAR.cmd](../INICIAR.cmd) na raiz, ou `dist/DefinitiveDownloader/definitive_downloader.exe`. Preserve as DLLs e a pasta `data` ao lado do executável. O pacote foi compilado e aberto nesta máquina; não foi validado em uma instalação limpa de Windows. Outras máquinas podem precisar do Visual C++ Redistributable x64.

O exemplo local permite conferir o fluxo sem conta: abrir a coleção, selecionar faixas e baixar. Seus seis arquivos usam áudio sintético curto e capa própria. O destino pode ser alterado antes de começar. Uma playlist real também pode ser importada por CSV UTF-8, uma faixa por linha, conforme o [README](../README.md).

## Escopo entregue

- Interface própria em tons claros, com tabela de faixas, navegação lateral e painel de conferência; sem reprodução do visual C2/JDownloader.
- Coleções e preferências em SQLite, migrações, ordem por ocorrência e preservação de repetições.
- Importação CSV incremental em lotes de 100, limite de 10.000 faixas e paginação de 40 linhas. Respostas remotas têm limites explícitos.
- Tentativa de importação pública Spotify parcial; indisponibilidade real de TLS documentada nos testes sem conta.
- Pesquisa Deezer, comparação de título/artista/duração/versão e vínculo explícito de prévias.
- Pesquisa externa YouTube Music e vínculo manual de URL MP3.
- Transferência sequencial, cancelamento, estados persistidos, gravação temporária, nomes seguros e validação básica de MPEG.
- Tags ID3 com capa APIC e M3U8 ordenada. Metadados solicitados são separados dos metadados da fonte encontrada; prévias não recebem a duração presumida da faixa completa.

Ainda não há importação autenticada, cópia de playlists para contas de outras plataformas, download automático de faixas completas dessas plataformas, varredura de páginas, vídeo, Instagram, Twitter ou integração JD2. A base não deve ser apresentada como downloader universal concluído.

## Organização

`main.dart` faz a composição. `core` contém rede, armazenamento e serviços de sistema. `features` contém módulos de importação, biblioteca/domínio, matching, downloads e apresentação. Widgets não executam SQL ou HTTP. O `AGENTS.md` estabelece essas regras para futuras alterações.

O banco local usa registros relacionais; nenhuma coleção completa é serializada em um campo JSON. O parser público do Spotify lê uma resposta limitada, sem persistir o documento inteiro. No Windows, SQLite usa a biblioteca do sistema. As operações de banco abrem conexões curtas em isolate.

Arquivos concluídos são preservados ao reiniciar. Uma transferência interrompida volta a ficar disponível, mas a nova tentativa reinicia aquele arquivo; não existe retomada HTTP por intervalo nesta versão. Não há processo residente ou serviço de downloads em segundo plano.

## Ambiente e compilação

Foram preparados Flutter 3.47.8/Dart 3.13.7 em `%LOCALAPPDATA%\DownloaderDevTools\flutter` e Visual Studio Build Tools 2022 com ferramentas C++ e Windows SDK. A compilação Windows foi confirmada. O SDK Android existente ainda requer licenças/configuração; nenhum APK foi gerado.

O script `tools/build_windows.ps1` copia os fontes para `%LOCALAPPDATA%\DefinitiveDownloaderDev\build-workspace`, verifica análise e testes e gera o pacote em `dist/DefinitiveDownloader`. Isso contorna limitações de symlinks da unidade de rede. Regras locais de CMake resolvem os caminhos de plugins no estágio, sem alterar o SDK Flutter. Os fontes oficiais permanecem no workspace. Não houve substituição da stack por conveniência.

## Validação

- `dart format`: fontes formatados.
- `flutter analyze --no-pub`: sem problemas na revisão final; log em `evidencias/final-analyze.log`.
- `flutter test --no-pub`: **19 testes aprovados**, cobrindo CSV, matching, repositório/paginação, importador público, transferência/tags e layouts de 1360 e 900 pixels.
- `flutter build windows --release --no-pub`: executável Windows gerado.
- Aplicativo nativo aberto e operado sem conta: seleção e gravação das seis ocorrências do exemplo. Verificação independente com Mutagen confirmou seis MP3s de aproximadamente 4,05 segundos, cada um com uma capa APIC. A M3U8 mantém a ordem e a ocorrência repetida.
- Aplicativo final reaberto, mantendo coleção e arquivos concluídos. Conferência visual em janela ampla e compacta, incluindo abertura do painel de faixa. Capturas em `images/`.

Essas validações não comprovam download de áudio do Spotify nem funcionamento em Android/iOS. Os ensaios de repositórios e rede estão em [TESTES_SEM_CONTA.md](TESTES_SEM_CONTA.md).
