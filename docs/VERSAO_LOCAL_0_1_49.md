# 0.1.49+50 — primeiro piloto Android

Entrega Android local, sem tag ou release GitHub. A instalação Windows 0.1.48 não é substituída por este APK. O escopo mobile conserva as funções do produto, mas a paridade ainda não está concluída; ver [matriz e etapas](ANDROID_PLANO_E_PARIDADE.md).

## Implementação

- Projeto Android Flutter com pacote `br.com.definitivedownloader.app`, nome e ícones oficiais D.d. APK de teste assinado com chave debug, ARM64 e x86-64; assinatura de produção não configurada. Versão vem de `pubspec.yaml`; identificação nas configurações e lateral acompanha 0.1.49.
- SQLite 2.9.4 com bibliotecas nativas 0.5.42, schema 16 preservado; sem migração ou leitura dos dados/contas do Windows. Backup automático Android desativado; sessão usa cofre nativo.
- Adaptador Android separado para MP3, CSV e capas via `ACTION_OPEN_DOCUMENT`. URIs são lidas em background para cópias de cache, com limites de extensão, tamanho e quantidade. Não tratar `content://` como caminho de arquivo, nem solicitar permissão ampla para armazenamento.
- Biblioteca possui suas próprias cópias numeradas de MP3, mantendo o original e os metadados. Destinos são pastas pertencentes ao aplicativo em volumes disponíveis; abertura de arquivo usa FileProvider com concessão de leitura temporária. Exportação para pasta pública/SAF e navegação de pastas ainda estão pendentes. Desinstalar remove os arquivos do app; a explicação está no diálogo da pasta, sem aviso permanente na biblioteca.
- Navegação inferior em pé e faixa lateral compacta de ícones deitado, player compacto exclusivo de Músicas, conferência em painel, listas contínuas e seletor como alternativa ao arraste. Coleção deixa de usar altura fixa de 660 px/rolagem externa. Em telas baixas, conferir usa painel móvel e as linhas ficam compactas. Teclado oculta temporariamente player/navegação e, quando necessário, títulos/abas redundantes; em Downloads a busca tem prioridade e os demais controles reaparecem ao fechar o teclado. Voltar do Android retorna da playlist às coleções; detalhes inativos não interceptam outras categorias.
- Android usa `MediaPlayer` e `MediaMetadataRetriever` por canal próprio, preservando controlador, fila e interface Dart. O player nativo é liberado ao destruir a Activity; pausa ao sair para segundo plano, perder foco ou desconectar fones. A conferência manual detectou SIGSEGV no libmpv ao fechar/reabrir; por isso o Android não cria players libmpv nem usa suas sondagens. Windows conserva seu motor existente. Validação Android combina leitura estrutural completa de frames/ID3 em Dart com duração/MIME nativos, sem corrida entre eventos de duração e trilhas.
- Seleção explícita de adaptadores por plataforma: Android não tenta executar o worker Windows. Motor musical ausente permanece indisponível; uma importação de metadados não habilita um download sem motor.
- Script `tools/build_android.ps1` sincroniza estágio local identificado, usa lockfile, roda essencial + área mobile e análise, cria APK e SHA-256 em `dist/Android`. Não roda Flutter pela UNC nem altera segurança, TLS ou firewall. JVM de build tem heap/concorrência limitados; pasta temporária de sockets própria evita falha de loopback no ambiente Windows/MSIX observado.
- Dois utilitários antigos de ensaio musical foram atualizados para o construtor assíncrono atual de `WindowsMusicEngine`; não foram executados testes reais de contas/provedores.

## Validação e limites

Resultados finais, hash e instruções de reprodução registrados ao concluir o pacote abaixo. Testes de áudio usam `assets/demo/tone.mp3`, uma fixture local decodificada; não são downloads reais de plataforma.

Checkpoint 0.1.49: assinatura APK verificada, pacote `br.com.definitivedownloader.app`, versionCode 50, mínimo API 24/target 36 e runtimes completos apenas ARM64/x86-64. O build recusa ABI extra sem Flutter/SQLite completos. SHA-256: `d4b6e867b7e023887f6b4f8f9e53329c815f342e76c35313017895d22092cf94`.

Rodada nativa complementar: criar playlist vazia, escolher MP3 em Downloads no seletor do Android, importar e reabrir a coleção. Cópia `001 - Dd-teste.mp3` e original conservam 65.244 bytes e o mesmo SHA-256; M3U8 gerada. Voltar da playlist, fechar e reabrir a Activity preservaram coleção/mídia, sem a queda anterior do backend. Rotação real verificou Coleções/Downloads; o transbordamento de 18 px encontrado foi corrigido com navegação lateral compacta em telas deitadas. O teste de teclado inclui manutenção do foco da busca ao reorganizar o cabeçalho.

O pedido posterior amplia a execução até a paridade de todas as funções operacionais: acompanhar `ANDROID_PARIDADE_CHECKLIST.md`. Concluir este checkpoint não encerra esse trabalho.

- Análise Flutter sem problemas no código final. Núcleo essencial e focados da área mobile passaram; os testes adicionais de tela validam 360×640, 844×390 e 914×411, com teclado e player, incluindo Coleções e Downloads. Depois da troca do backend, arquitetura, adaptador Android, controlador do player e composição foram verificados: 27 testes passaram e um ensaio nativo Windows opt-in não foi executado. Não foi rodada a regressão completa.
- Smoke nativo Android 16/API 36 x86-64 passou com MediaPlayer: SQLite em novo repositório/isolate, cofre com valor de fixture, duas cópias MP3 com original idêntico, player com progresso real, avançar/voltar, aleatório, repetir lista/faixa, pausa, volume e navegação com player restrito a Músicas. O teste aguarda progresso com prazo, sem pressupor latência fixa de 350 ms na saída de áudio do emulador.
- As primeiras tentativas do ensaio completo tiveram falha de transporte VM/ADB e uma falha intermitente na importação; elas não foram consideradas aprovadas. Usar `--disable-dds` estabilizou a conexão de teste neste host. A verificação manual posterior encontrou SIGSEGV no libmpv que o smoke curto não havia detectado; o backend Android foi substituído antes da entrega. A validação de ciclos de Activity e o seletor do sistema são conferidos no APK final, separadamente do smoke.

Pendências prioritárias: motor musical Android por provedor, login Spotify com retorno Android registrado, conexão Deezer com motor nativo, serviços de primeiro plano/notificações, foco de áudio e fones/chamadas, exportação de pastas compartilhadas, intents de compartilhamento e validação em aparelho físico. Importadores públicos e regras permanecem Dart, mas isso não constitui ensaio real de todas as plataformas no Android. iOS não foi criado nem validado nesta etapa de APK.

## Reproduzir

Requisitos locais: Flutter 3.47.8/Dart 3.13.7, JDK 21 (Android Studio), Android SDK/NDK e licenças necessárias. O template fixa Gradle 9.3.1/AGP 9.1.0; Flutter regenera o wrapper quando ausente. SDK de compilação 36; mínimo Android API 24. Plugins podem exigir componentes SDK adicionais, instalados pela ferramenta Android.

1. Executar `tools/build_android.ps1` a partir de checkout local, ou copiar o script para uma pasta local e passar `-WorkspaceRoot` com a UNC. Estágio padrão: `%LOCALAPPDATA%\DdbAndroid`. Não usar a pasta de outro projeto como estágio.
2. Instalar o APK de `dist/Android` no emulador ou aparelho Android ARM64/x86-64. O emulador dedicado desta rodada é `Definitive_API_36`, Android 16/API 36 x86-64, separado dos emuladores de outros projetos.
3. Teste nativo focado no estágio já preparado: a partir da 0.1.50, usar `./tools/test_android.ps1 -TestFile integration_test/android_smoke_test.dart`, com pacote `.integration` e sem desinstalação automática. Não executar contra uma biblioteca pessoal. O teste usa banco/mídia temporários e elimina somente sua própria árvore, inclusive após falha.
4. Se o mesmo código já passou em análise e testes, usar `-SkipTests -SkipAnalysis` para reempacotar; não repetir a regressão completa.
