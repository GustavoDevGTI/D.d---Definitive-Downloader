# Android: piloto e paridade funcional

Pedido de 05/11/2026: iniciar APK, adaptar o uso no smartphone e conservar todas as funções como escopo do produto. Paridade não pode ser inferida pela presença da tela.

## Etapas

1. Criar projeto Android, identidade D.d, SQLite nativo e build reproduzível fora da UNC.
2. Integrar seleção de arquivos por documentos do Android, cópia privada e abertura por URI concedida, sem acesso amplo ao armazenamento. Preservar arquivos originais.
3. Adaptar área útil, navegação, teclado e listas ao toque, sem paginação visual nem player fora de Músicas.
4. Compilar APK de teste, instalar em emulador separado e testar persistência, arquivo local e reprodução. Não usar contas, banco ou mídias do Windows.
5. Implementar e validar as integrações Android ainda ausentes; manter os fluxos e regras compartilhados, sem anunciar paridade antes da validação.

## Direção de interface

Manrope; fundo #FAFAFC, superfície #F3F4F6, texto #1E293B, ação #C9345B, ativo #A01F45 e player #23273F. Navegação inferior por categoria, listas contínuas com cabeçalho separado, conferência em painel móvel e player compacto expansível. O espaço vertical pertence às faixas; remover alturas de desktop e rolagem externa redundante. Não introduzir cartões decorativos nem copiar a identidade de outro player.

## Matriz inicial (antes da validação do APK)

| Função | Base compartilhada | Integração/validação Android necessária |
|---|---|---|
| Biblioteca, playlists, grupos, capas e buscas | Dart/SQLite | Biblioteca SQLite empacotada; persistência real |
| Misturar playlists e links; ordem, duplicatas e numeração | Dart | Seleção por toque e decisões modais; preservar regras de arquivos concluídos |
| Importadores públicos Spotify/Deezer/YouTube/SoundCloud e CSV | Dart/HTTP | Rede no dispositivo, seletor CSV; catálogo público não equivale a download |
| Arquivos MP3 locais | Dart | Document picker, cópia limitada para arquivo real; seletor substitui arraste do Explorer |
| Arquivos diretos, fila, pausa, parada e métricas | Dart | Destino Android e ciclo de vida; foreground primeiro |
| Download musical Deezer/YouTube Music/YouTube/SoundCloud | Contratos e políticas Dart; worker Windows Python | Motor Android próprio; não empacotar EXE nem simular disponibilidade |
| Reprodução local, aleatório, repetir faixa/lista, volume e prévias suportadas | Controlador Dart; MediaPlayer Android, media_kit Windows | Native Android próprio; validar foco de áudio/fones/chamadas físicos e segundo plano |
| Login Spotify | PKCE/token store compartilhados | Callback Android próprio, registro do aplicativo e ensaio real; nunca reutilizar loopback Windows |
| Conexão Deezer | Contrato/cofre compartilhados | Motor Android e validação de sessão; não procurar cookies |
| Pastas de saída e abrir/compartilhar arquivos | Contratos Dart | Scoped storage, FileProvider e exportação SAF/MediaStore; URI de documento não é caminho File |
| Transferência entre contas, backup, IA, formatos especiais e captura de outras categorias | Capacidades planejadas também no desktop | Não anunciar implementadas em nenhuma plataforma |
| Download/player com app em segundo plano | Não garantido pelo processo Flutter | Serviço de primeiro plano, notificações, controles de mídia e recuperação após encerramento |
| Receber links/arquivos de outros apps | Não implementado | Intents, permissões temporárias e importação revisável |

Os resultados reais e os próximos bloqueios serão registrados na nota da versão. APK de teste não é publicação Play Store, release GitHub nem conclusão de todas as funções mobile.

## Próximas integrações, preservando o escopo

1. **Motor musical Android:** manter a interface de operações e as regras Dart; implementar transportes e processamento nativos/compartilhados, sem lançar Python/EXE do Windows. Validar cada provedor separadamente com arquivo completo, identidade, duração, capa, cancelamento e publicação atômica. Não aceitar prévia ou mídia protegida como arquivo completo.
2. **Ciclo de vida:** serviço de primeiro plano para transferência/reprodução, notificação e controles, pausa segura, reconciliação após encerramento do processo e retomada explícita. Não confundir estar reproduzindo em foreground com suporte garantido em segundo plano.
3. **Contas:** configurar retorno Android Spotify e identificação do pacote/assinatura, PKCE e estado; sessão Deezer depende do motor Android. O cofre nativo pode ser validado com uma fixture sem efetuar login nem reutilizar contas/cookies Windows.
4. **Armazenamento público:** exportar/copiar com SAF ou MediaStore, tratar URI/permissão revogável e cartões removíveis; manter banco e cópias de trabalho próprias. A seleção atual de destino entre volumes do app não substitui escolher uma pasta pública arbitrária.
5. **Uso por toque:** seleção múltipla por checkbox, reordenação por toque prolongado e editor em Informações conservam alternativas aos atalhos de mouse/teclado. Validar aparelho físico, texto ampliado, teclado, orientação, fones/chamadas, arquivos grandes e compartilhamento recebido antes de declarar paridade.

Referências técnicas: [configuração Android no Flutter](https://docs.flutter.dev/platform-integration/android/setup), [SQLite nativo para a versão 2 do pacote](https://pub.dev/packages/sqlite3/versions/2.9.4), [documentos e SAF](https://developer.android.com/training/data-storage/shared/documents-files), [retornos Spotify](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri). A dependência SQLite nativa fica fixada em 0.5.42; a série 0.6 é vazia e destina-se à migração para sqlite3 3, que este projeto não fez.

O piloto passou a usar MediaPlayer Android após falha nativa do libmpv no fechamento/reabertura. A propriedade do recurso segue a Activity e o controlador Dart permanece compartilhado. [Estados e liberação do MediaPlayer](https://developer.android.com/media/platform/mediaplayer/state-resources) e [foco de áudio](https://developer.android.com/media/optimize/audio-focus) orientam essa integração; isso ainda não substitui serviço de mídia em segundo plano.
