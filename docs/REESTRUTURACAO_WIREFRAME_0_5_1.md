# Reestruturação estrutural — Wireframe v0.5.1

Solicitação de 28/10/2026. A versão do wireframe identifica a especificação, não a versão publicada do aplicativo.

## Análise anterior à implementação

A base usa Flutter/Dart e Material, com LibraryController (ChangeNotifier), LibraryRepository e SQLite schema v5. Não há roteador externo: LibraryScreen é a entrada da interface. LibrarySidebar troca filtros da mesma coleção; Downloads e Arquivos ainda reutilizam a tabela de faixas. TrackInspector e TrackTable já separam foco e seleção. Spotify PKCE, importação autenticada/CSV, busca musical, cofre e serviços de download são componentes reutilizáveis.

DownloadService coordena a gravação de MP3 e MusicDownloadService usa o worker Windows por operação. Há cancelamento, mas não pausa/retomada HTTP, prioridade, concorrência configurável ou telemetria de velocidade/tamanho/tempo restante. Esses controles precisam indicar indisponibilidade enquanto não houver suporte real. Não há motor geral de captura de páginas, vídeo/fotos, importação de álbuns ou transferência remota de playlists.

Riscos centrais: perder referências de arquivos ao alterar fontes; sobrescrever vínculos manuais com busca/fallback; confundir correspondência e transferência; misturar filas ao reutilizar componentes; truncar listas; e bloquear ou comprimir controles em telas pequenas. Não migrar arquivos físicos nem acessar contas para testar a estrutura.

## Plano estrutural

Manter as cores existentes: fundo #F5F7F9, superfície #FFFFFF, texto #202A34, secundário #65717D, divisórias #E1E6EB e acento #315A76. Preservar Manrope e o tema atual. A mudança é de navegação, posicionamento e hierarquia; não inclui identidade visual nova.

Desktop: menu fixo com Início, Músicas, Vídeos e Fotos, Arquivos e Configurações; abas dentro das duas categorias; conferência à direita quando houver largura. Mobile: navegação inferior, lista compacta e conferência em painel secundário rolável. Alinhamento à esquerda, títulos/artistas agrupados, ações compactas com tooltips e estados indisponíveis explícitos.

Reutilizar o controller e serviços musicais. Extrair componentes para categorias, captura, downloads e histórico. Preparar captura sem resultados fictícios. Consultar indicadores e histórico com paginação, sem uma segunda fila persistida. Separar estado da correspondência e vínculo manual no banco; preservar referências históricas dos arquivos concluídos.

## Fontes manuais e suporte técnico

O prompt propõe informar uma URL manual e escolher o tratamento de áudio. As instruções AGENTS.md reenviadas durante a implementação mantêm a restrição a videoclipes nos downloads musicais, inclusive na escolha manual. A busca e obtenção pelo YouTube Music continuam exigindo MUSIC_VIDEO_TYPE_ATV. Uma URL informada não confirma correspondência, suporte técnico ou download. A opção de extração de páginas/vídeos salva somente um vínculo pendente, sem executá-lo; não há fallback para vídeo. O caminho existente de MP3 direto é preservado e valida o conteúdo durante a transferência.

## Resultados

Implementado no aplicativo **0.1.2+3**, mantendo Flutter/Dart, o tema e o lockfile existentes. O worker musical não foi recompilado nem substituído; seu SHA-256 permaneceu `55D5FE1DF258BD241A91A2F7253821B8A48218720ACFA39AB6EEE4DBEF69D62D`.

| Área | Alterações |
|---|---|
| Navegação | LibraryScreen e LibrarySidebar passaram a compor as cinco áreas. MobileNavigation usa navegação inferior; CategoryTabs organiza as categorias. Não há Downloads global. |
| Coleções | CollectionWorkspace reutiliza importação Spotify/CSV, conexões e controller. Coleções e faixas são paginadas; a pesquisa é feita no banco, preservando posições e repetições. |
| Faixas | TrackTable agrupa título/artista, mantém foco separado do checkbox e usa lista compacta em telas estreitas. Selecionar/desmarcar todas respeita a pesquisa atual. |
| Conferência | TrackInspector tem Correspondência/Informações, revisão, confirmação e ManualSourceInput. O vínculo manual persiste por ocorrência e impede substituição automática. |
| Downloads | DownloadWorkspace, DownloadTable, DownloadToolbar e HorizontalTableViewport são compartilhados pelas categorias. A consulta musical reúne coleções sem criar uma segunda fila. Seleção múltipla, início, nova tentativa, cancelamento da operação selecionada, abertura da pasta e remoção confirmada de registros concluídos usam os serviços existentes. |
| Início | HomeWorkspace consulta contagens e últimos arquivos reais no SQLite. Transferência entre contas aparece como indisponível. Não há números fictícios de atividade. |
| Arquivos | HistoryWorkspace e FolderBreadcrumb navegam pelas pastas/subpastas registradas, pesquisam e abrem arquivo/localização. Arquivos ausentes ficam sinalizados; nenhum registro é apagado automaticamente. |
| Configurações | SettingsWorkspace centraliza pasta de destino e acesso às conexões; preferências sem implementação são descritas como indisponíveis. |
| Estado da interface | WorkspaceController e WorkspaceRepository consultam páginas limitadas e indicadores agregados. As telas acompanham suas próprias atualizações; widgets não acessam SQL, disco ou processos. |

### Persistência

Migração transacional **v5 → v6**: `match_status`, `manual_url`, `manual_mode` e `queue_hidden` em `tracks`, mais `download_history` com registros individuais e índices. Arquivos concluídos são copiados para o histórico em lotes de leitura limitados; caminhos, ordem, seleções, preferências e tentativas por provedor são preservados. Não houve alteração de cofre ou contratos de autenticação.

O histórico preserva a origem e o caminho do arquivo concluído mesmo se a faixa receber outro vínculo. Remover do histórico oculta os registros confirmados pelo usuário e preserva os arquivos físicos. Dados de fonte encontrada ficam separados dos metadados originais, inclusive a capa.

URLs manuais devem ser públicas e estáveis: credenciais embutidas e parâmetros genéricos são rejeitados. Links YouTube de formato reconhecido são reduzidos ao identificador público do vídeo; isso permite guardar a referência, não obter seu áudio. O modo de extração permanece bloqueado para download. O modo de áudio original reutiliza apenas o mecanismo de MP3 direto e confere o conteúdo recebido.

### Recursos preparados, ainda indisponíveis

- Análise de URLs individuais/páginas, captura e downloads de vídeos/fotos e escolha de resolução: áreas isoladas, sem resultados ou execução simulados.
- Importação de álbuns, reprodução de prévias, pausa/retomada por intervalo, alteração de prioridade, concorrência configurável e limites de velocidade: ainda não implementados.
- Tamanho, velocidade, tempo restante e quantidade de bytes: aparecem como dados não disponíveis; progresso não encerra processamento por si só.
- OAuth/worker/armazenamento e execução nativa mobile: continuam exigindo implementação e validação próprias. O teste de layout mobile não comprova download no celular.
- DLC, CCF, RSDF, Metalink, Meta4, NZB e SFDL: permanecem no escopo documentado, sem implementação nesta etapa.

### Verificação e limites

Testes usam bancos temporários, servidor HTTP local, áudio sintético e metadados de catálogo fictícios claramente separados. Não houve acesso às contas do usuário, download de provedores ou migração do banco de produção nesta revisão. Os testes cobrem v5/v6, migrações anteriores, vínculo manual após reinício, proteção contra busca automática, seleção, ordem/repetições, paginação, cancelamento, arquivos concluídos de coleções diferentes, M3U8 e histórico após exclusão externa.

Conferência visual por capturas dos widgets em **1360, 900, 390 e 320 px**, com texto ampliado **1,3×** na menor largura. Foram conferidos coleções, conferência, conexões, downloads, navegação e configurações, sem overflow nos testes. Capturas em `images/wireframe-*`; os rótulos de provedor nelas são fixtures visuais, não downloads reais.

Comandos e resultados finais constam em [RELEASE_0_1_2.md](RELEASE_0_1_2.md). Os logs de análise, compilação e layout estão em `evidencias/wireframe-*.log`. A compilação Windows foi feita no staging local devido ao workspace UNC, sem alterar a política de execução ou a segurança do sistema. Não houve ensaio do instalador em uma máquina limpa nem novo teste de contas reais. Este workspace não contém repositório Git; a tag de publicação `v0.1.2` não foi criada.
