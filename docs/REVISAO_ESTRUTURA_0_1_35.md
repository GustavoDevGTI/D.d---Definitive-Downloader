# Revisão de estrutura — ciclo local 0.1.35

Pedido de 04/11/2026: revisar organização, arquivos grandes e custo de execução antes de continuar as mudanças funcionais. Base: commit `1ef700d`, versão 0.1.34, schema 11. Sem release/tag/push neste ciclo.

## Diagnóstico inicial

- `lib`: 89 arquivos Dart, 13.801 linhas. Maior arquivo: `LibraryController`, 999 linhas, misturando apresentação de estado, conferência e execução de downloads. `main.dart` permanece uma composição pequena de dependências.
- `TrackTable`: 595 linhas; `DownloadTable`: 580. Boa parte é construção visual muito aninhada, junto dos gestos, seleção, paginação e redimensionamento.
- Repositórios já centralizam SQL e usam SQLite parametrizado em isolates. Listas usam páginas de 30/40, importações/lotes têm limites; worker Python tem arquivos pequenos (máximo de 150 linhas nesta base). Não há justificativa para trocar a stack ou reescrever a persistência.
- O listener de `WorkspaceController` agenda recarga completa a cada 400 ms enquanto recebe progresso, incluindo resumo, Downloads, histórico e consultas ao disco. Progresso de bytes não mudou esses registros. Também há reconstrução da barra completa do player para cada evento de posição.
- Tamanho de fonte não mede diretamente velocidade do aplicativo. As correções de desempenho se concentram em trabalho repetido identificável; sem promessa de ganho em FPS/memória sem medição própria.

## Plano autorizado e executado em etapas

1. Separar execução da fila e correspondência/vínculos musicais em módulos com dependências explícitas. Manter `LibraryController` coordenando a tela, seleção e navegação, preservando ordem, fontes manuais, aprovação e recuperação. Extrair as linhas visuais das tabelas; manter gestos e redimensionamento nos respectivos widgets de tabela.
2. Distinguir revisão dos dados persistidos dos eventos de progresso para evitar recargas do workspace sem alteração. Isolar o relógio do player para atualizar posição/duração sem reconstruir capa, metadados, fila e transporte a cada tick. Manter estados imediatos de pausa, fim, erro e troca de música.
3. Testar contratos de fila/correspondência existentes, adicionar verificações dos custos evitados e de eventos do player, executar format/análise/suíte e compilar Windows. Conferir layout desktop/mobile e preservar base/mídias; incrementar versão local e atualizar a instalação, sem publicar release.

Schema, nomes/caminhos de arquivos e visual funcional preservados. As interfaces e regras compartilhadas seguem em Dart; validar widgets mobile não comprova execução nativa Android/iOS.

## Resultado da separação

| Arquivo/módulo | Antes | Depois | Responsabilidade |
| --- | ---: | ---: | --- |
| `LibraryController` | 999 linhas | 786 linhas | Estado da tela, seleção, navegação e coordenação dos comandos existentes. |
| `DownloadQueueRun` | Dentro do controlador | 210 linhas | Snapshot/execução da fila, espera de extras, fallback permitido, publicação e M3U8. Emite eventos; não possui widgets. |
| `LibraryMusicSources` | Dentro do controlador | 119 linhas | Conferência paginada e escrita dos vínculos musicais/prévias. |
| `TrackTable` | 595 linhas | 418 linhas | Gestos, arraste entre páginas, seleção e cabeçalhos; aparência da linha em `TrackRow` (151 linhas). |
| `DownloadTable` | 580 linhas | 384 linhas | Rolagens, larguras e ordenação; células/formatos em `downloadRowCells` (135 linhas). |
| `download_cancellation.dart` | Dentro do adaptador | 44 linhas | Cancelamento, pausa e limitação da transferência, sem depender dos motores. |
| `download_file_name.dart` | Dentro do adaptador | 13 linhas | Sanitização compartilhada dos nomes. |

O mapa de dependências encontrou ciclos entre `DownloadService`, `MusicDownloadService`, conexão Deezer e `MusicEngine`: módulos importavam o adaptador de downloads somente para obter cancelamento/nomes/medições. Os módulos compartilhados retiram esse ciclo. Reexports no arquivo anterior preservam os chamadores existentes. Mensagens de operação foram concentradas no módulo próprio de aplicação em `core`; o status de operação da biblioteca também tem widget próprio.

O projeto passou a ter 97 arquivos Dart de produção e 13.900 linhas. O controlador de 786 linhas continua sendo a maior fachada de estado/comandos da biblioteca, com implementação dos fluxos extraída. Repositórios de 537/450 linhas mantêm transações e consultas coesas. A revisão reduz acoplamento e concentração, sem tratar uma quantidade arbitrária de linhas como prova de desempenho. `main.dart` permanece com 82 linhas de inicialização/composição.

## Custos evitados e contratos

- Métricas de transferência usam `transferUpdates`: atualizam a tabela/status sem notificar a biblioteca inteira por chunk. Revisões de dados, pausa e alteração do destino continuam agendando recarga do workspace. Eventos transitórios não relêem resumo/histórico nem disparam verificações de disponibilidade. Alterações reais em rajada são agrupadas pelo intervalo existente de 400 ms.
- O relógio do player possui `timeline`: posição/duração atualizam seek, tempos e progresso compacto; capa, metadados, transporte e fila não recebem a notificação geral por cada tick. Pausa, erro, fim e troca de faixa continuam imediatos.
- O getter de disponibilidade do motor musical fazia `File.existsSync()` no caminho consultado pela interface. A presença é carregada assincronamente na inicialização; a operação reconfere o arquivo assincronamente antes de criar o processo. A aplicação precisa ser reiniciada após instalar/remover o worker; a falha de arquivo ausente continua informada por operação.
- A consulta de coleções limita primeiro as 30 coleções da página e só depois agrega suas faixas. Mantém ordem, contagens, repetições e paginação sem agrupar todas as coleções para montar a página.
- Descarte do controlador cancela a operação, invalida resultados atrasados e libera o novo notificador. Não altera estados de autorização, nem apaga arquivos ou coleções.

Novas verificações automatizadas impedem ciclos em imports/exports Dart e dependência de IO/SQLite em apresentação/domínio; domínio também não depende de Flutter. A varredura não substitui análise semântica completa de todos os acessos indiretos. Dados da aplicação continuam em repositórios SQLite e operações pesadas de persistência ficam em isolates. Não foi introduzido cache global de banco, novo framework ou dependência de pacote.

## Validação realizada

- `dart format`, análise estática final sem problemas e suíte completa **164 testes aprovados**. Cobertura anterior de repetições, ordem com concluídas fixas, extras durante a execução, fonte manual, aprovação de vídeo, recuperação explícita, filtros e paginação permaneceu aprovada.
- Testes de custo: 100 sinais transitórios não aumentaram leituras de repositório nem consultas de disponibilidade; 100 revisões de dados em rajada produziram uma recarga (três leituras e uma verificação de arquivo da fixture). 100 eventos de posição resultaram em 100 atualizações do relógio e zero notificações gerais do player. Pausa e volume ainda notificaram os controles; duplicar a mesma posição não notificou novamente.
- Transferência **sintética** de MP3 local validado: uma rajada de pelo menos 200 atualizações de métricas gerou menos de 20 notificações gerais, preservando o arquivo concluído. Não é download novo de provedor real. Presença do worker ausente/revalidado e três páginas de 61 coleções com contagens corretas também foram verificadas.
- Testes de arquitetura aprovados: nenhum ciclo de importação/exportação na árvore Dart; apresentação/domínio passaram nos contratos de dependências descritos acima.
- Onze testes de layout/interface repetidos, com capturas em 1920, 1360, 900, 390 e 320 px e texto ampliado conforme os ensaios existentes. Downloads e conferência inspecionados em 1360 e 390 px; identidade, campos, controles, estados e rolagens preservados. UI compartilhada testada; sem build/dispositivo nativo Android/iOS.
- Compilação Windows release concluída. 151 arquivos de lib/test/assets/pubspec/lock iguais ao staging compilado. Worker Python preservado por SHA-256 `fa8aa628c181a7fc24b1aecc01d00a2040af72c604b2dfb86bd0cc051b904f82`, sem mudança de protocolo, provedor ou dependências.
- Diagnóstico nativo de áudio no pacote: MP3 sintético de 4.048 ms, posição avançando, pausa, seek e volume contínuo aprovados. `health` do worker nativo respondeu pronto/protocolo 1, sem conta e sem consulta a provedor. Não houve novo ensaio de autenticação/download de plataforma nesta revisão.
- Instalador 0.1.35 gerado, SHA-256 `05A475F4A491B886B0ED3EEF4645CFF135972E57650C7D55670D63F623CFB894`. Instalação atualizada, executável `0.1.35+36`, registro Windows `0.1.35`, atalho apontando ao app instalado; processo aberto/respondendo. Sem release, tag ou push.
- Backup anterior preservado. Base schema 11, `quick_check=ok`, nenhum trabalho ativo interrompido. Hashes integrais das tabelas conferidas iguais antes/depois e após reabrir: duas coleções, 242 faixas, 11 arquivos no histórico, dez preferências, 2.183 candidatos, 11 tentativas e zero grupos. Executável, app.so, Flutter DLL, bibliotecas de áudio, ICO e worker iguais por SHA-256 entre pacote e instalação. Nenhuma mídia foi movida/renomeada/apagada; nenhuma credencial inspecionada.

Na última conferência da janela, o Windows estava bloqueado: a automação visual foi interrompida. Metadados de acessibilidade ainda identificaram a versão 0.1.35 e controles do player; isso não equivale a interação visual com o app desbloqueado. Capturas de widgets, ensaios nativos do pacote e verificação da instalação são evidências distintas.

Não foi executado benchmark de FPS, CPU ou memória em máquina/dispositivo de referência. Os números acima medem notificações/consultas evitadas e tamanhos de código; não prometem uma aceleração percentual do aplicativo. As evidências, capturas, logs, hashes e backup permanecem privados em `%LOCALAPPDATA%\DefinitiveDownloaderDev\local-version-0.1.35`, fora do Git.
