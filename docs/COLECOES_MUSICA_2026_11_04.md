# Coleções musicais — ciclo de 04/11/2026

Escopo autorizado pelo usuário, com execução na ordem das seis imagens. A versão só muda ao concluir o conjunto. Releases, tags e push continuam suspensos para feedback local.

## Sequência e critérios

1. **Print 1 — player:** limitar barra e atalhos de reprodução a Músicas; sair pausa e conserva fila/posição. Início, Vídeos e Fotos, Arquivos e Configurações recuperam toda a área do rodapé. Arquivos continua abrindo mídia pelo aplicativo associado do sistema.
2. **Print 2 — ações em Coleções:** manter criar playlist no topo e expor renomear, capa, mover para grupo e excluir por ícones com tooltip, sem menu de três pontos. Exclusão exige confirmação e preserva arquivos físicos/histórico; bloquear durante execução.
3. **Print 3 — capa da playlist:** escolher PNG/JPEG/WebP; validar até 5 MB e dimensões limitadas, normalizar e copiar para armazenamento próprio. Substituir ícone pela capa, sem depender do arquivo original continuar no lugar.
4. **Print 4 — grupos:** faixa de filtros com Todas, Sem grupo e grupos nomeados; ações diretas de criar/renomear/remover. Rolagem horizontal em telas pequenas, sem dropdown/gaveta para o filtro principal.
5. **Print 5 — faixas:** capa na linha e no painel de Informações, preferindo a capa do arquivo local; estado Baixada/Não baixada/Baixando/Falha/Arquivo indisponível separado da correspondência. Conservar fonte e metadados da gravação e da solicitação.
6. **Print 6 — YouTube Music:** oferecer escuta da versão exata. Arquivo local tem prioridade. Quando não há arquivo, ação explicitamente externa “Ouvir no YouTube Music” (ou YouTube), sem rotular como prévia interna; ouvir não confirma nem baixa. Referência/cópia e confirmação continuam independentes.
7. **Sem print — SoundCloud:** investigar busca, reprodução, importação, obtenção, autenticação, limites e plataformas. Resultado documental, sem habilitar capacidades fictícias.
8. **Sem print — outras playlists:** avaliar YouTube/YouTube Music, Deezer e SoundCloud além de Spotify. Registrar paginação, ordem/repetições e acesso público/privado; distinguir importação de metadados de disponibilidade para baixar.

## Direção e estrutura

Listas compactas, ações por ícones e filtros em linha, paleta oficial e Manrope. Sem novos balões, mural de cartões ou orientações permanentes. Desktop mostra ações ao lado da playlist; mobile coloca ações logo abaixo para preservar nomes e área de toque.

`CollectionManager` coordena UI; `CollectionGroupStrip` e `OrganizationNameDialog` separam filtros e edição. `CollectionOrganizationRepository` concentra SQL. `ArtworkStore` limita imagem, concorrência (4), resolução (512 px), cache (100 itens/12 MB) e tamanho de leitura. Widgets recebem bytes/resultados, sem HTTP, SQLite ou leitura direta de arquivos. Imagens falhas usam ícone, sem interromper áudio ou biblioteca.

Schema 12 acrescenta somente `collections.cover_path`, com valor vazio nas coleções existentes. Exclusão da playlist usa relações existentes: ocorrências são removidas, histórico fica com `track_id` nulo. Não move, renomeia nem remove MP3s. Capas gerenciadas são endereçadas por hash; compartilhamento não cria cópias duplicadas. Imagens sem referência ficam preservadas neste ciclo, sem limpeza automática.

UI e regras em Dart compartilhado. Windows exige validação nativa; testes de widgets estreitos não comprovam Android/iOS, cujos projetos nativos ainda não estão configurados.

## Pesquisa de capacidades

### SoundCloud

A API oferece busca, resolução de URL, playlists e reprodução; diferencia áudio completo, trecho e bloqueio. Requer app próprio registrado. Atualmente o fluxo OAuth usa PKCE e exige segredo inclusive para clientes desktop/mobile; isso pede um serviço de autenticação, sem embutir segredo no executável. Não foram criados cadastros nem usadas credenciais neste ciclo. [Guia oficial](https://developers.soundcloud.com/docs/api/guide).

O widget oficial permite controlar reprodução incorporada por JavaScript. É um caminho para escuta com componente web visível e validação por plataforma; não fornece um MP3 universal para o player local. [Widget API](https://developers.soundcloud.com/docs/api/html5-widget).

Os termos atuais da API proíbem oferecer armazenamento/offline permanente de conteúdo, inclusive quando o uploader habilitou download na plataforma. Portanto busca/escuta/importação e obtenção local têm conclusões distintas: a API não deve ser anunciada como motor de download geral. Não houve download real SoundCloud nesta avaliação. [Termos, seção Caching and Downloading](https://developers.soundcloud.com/docs/api/terms-of-use).

### Importação de playlists

| Origem | Caminho avaliado | Conclusão para o projeto |
| --- | --- | --- |
| Spotify | Importador autenticado existente | Mantido; importar não habilita áudio Spotify. |
| YouTube | `playlistItems.list`, posição/ID por ocorrência, até 50 itens/página e `nextPageToken` | Viável para metadados; exige projeto/API key para público e OAuth para privado. Não implementado neste ciclo. |
| YouTube Music | Links com `list` podem identificar playlists do ecossistema YouTube | Investigar cada tipo de playlist; a API de vídeos não comprova acesso a toda playlist musical nem metadados completos de artista. |
| Deezer | API de playlists e faixas, separada do motor musical existente | Ensaio público sem conta retornou 2 faixas, total 50 e próxima página. Importador completo ainda não implementado. |
| SoundCloud | Resolução de URL e recursos de playlist da API | Viável após cadastro/autenticação próprios, respeitando acesso/restrições e sem confundir importação com download local. |

YouTube documenta posição, ID, paginação e custo de uma unidade por chamada de listagem. [Referência oficial](https://developers.google.com/youtube/data/reference/rest/v3/playlistItems/list). A documentação Deezer acessada redirecionou a autenticação; isso não prova encerramento da API nem disponibilidade para a conta do produto. [Portal oficial](https://developers.deezer.com/api).

Ensaio real de metadados em 04/11: `https://api.deezer.com/playlist/908622995/tracks?limit=2` respondeu HTTP 200, duas entradas, total 50 e `next` presente; leitura limitada a 512 KiB, sem autenticação. Não foi percorrida a playlist inteira nem testado acesso privado, repetição ou download. [Endpoint público consultado](https://api.deezer.com/playlist/908622995/tracks?limit=2).

Para YouTube, reprodução interna oficial usa IFrame visível, com viewport mínimo 200×200; incorporar vídeo e integrar seus estados requer outra etapa Windows/mobile. Neste ciclo abre-se a versão na plataforma, preservando a prioridade do arquivo local. [IFrame Player API](https://developers.google.com/youtube/iframe_api_reference).

Próxima implementação sugerida: adaptadores Dart de importação por provedor emitindo `TrackDraft` em páginas, máximo explícito de itens, identificação de cada ocorrência e preservação de repetições/ordem. Criar nova coleção e acrescentar a existente devem compartilhar parser; links extras continuam independentes da importação integral. Antes de habilitar cada provedor, validar playlist pública, privada, >1 página, repetidas, indisponíveis e cancelamento com acesso próprio. Nada disso foi apresentado como implementado nesta entrega.

## Validação e instalação

- Versão incrementada somente após implementar os itens 1–6 e concluir as avaliações 7–8: **0.1.36+37**, schema 12. Sem release/tag/push.
- `dart format`: 142 arquivos, nenhum ajuste pendente. `flutter analyze --no-pub` no staging local: sem apontamentos. A tentativa de analisar diretamente pela UNC falhou no servidor de análise ao procurar uma raiz de rede alheia; a análise válida é a do staging local com os mesmos fontes.
- `flutter test --no-pub`: **171 testes aprovados**. Contratos incluem exclusão preservando histórico/arquivo, bloqueio durante execução, migração v11/v12, cópia de capa independente do original, limites de imagem, pausa ao sair, abertura tardia e fim de faixa fora do módulo, URL exata YouTube Music e prioridade local.
- Compilação Windows release concluída. Motor musical congelado preservado; nenhuma nova autenticação nem transferência musical real nesta rodada.
- Capturas de widgets inspecionadas em 1360 e 320 px; suíte cobre 1920, 1360, 900, 390 e 320 px, inclusive texto ampliado no menor tamanho. Corrigidos acessos a filtros/linhas que precisavam de rolagem nos testes. Artefatos são locais, fora do Git.
- O teste de capas detectou uma espera circular no encerramento do future compartilhado; a remoção do pedido pendente agora usa callback sem retorno de future. Teste com imagem real copiada/decodificada passou depois da correção.

Instalação Windows atualizada e aberta em Coleções: EXE **0.1.36+37**, registro do desinstalador **0.1.36**, atalho da Área de Trabalho para o executável instalado e ícone oficial. Installer local com SHA-256 registrado; hash de EXE, `app.so`, DLLs de áudio, ícone e worker conferidos contra o pacote. 157 fontes/assets/testes conferidos com o staging. Evidências privadas em `%LOCALAPPDATA%/DefinitiveDownloaderDev/local-version-0.1.36` e `music-library-batch`.

Backup SQLite e binários anteriores antes da atualização. Schema 11→12 validado com `quick_check=ok`, mantendo integralmente os valores das colunas anteriores: **2 coleções, 242 ocorrências, 11 registros de arquivos, 10 preferências, 2183 candidatos, 11 tentativas e 0 grupos**. A seleção alterada durante a conferência visual foi restaurada pela interface e o comparativo final voltou a coincidir. Não foram excluídas playlists reais nem iniciados novos downloads.

Conferência nativa após desbloqueio: Início sem rodapé do player; Coleções com ações diretas e grupos em faixa; capas reais na lista e nas Informações; música local reproduzida com posição avançando. Sair para Início removeu a barra e pausou; retornar a Músicas preservou faixa/posição e não retomou automaticamente. Conferência mostrou “Ouvir prévia” para Deezer e “Ouvir no YouTube Music” para o candidato exato. A abertura externa foi coberta pelo teste de URL; não foi declarada reprodução interna YouTube nem ensaio de streaming SoundCloud. Aplicativo deixado aberto em Coleções, áudio pausado.
