# Versão local 0.1.41 — Coleções e Downloads contínuos

Pedido de 04/11/2026: substituir páginas por rolagem contínua na playlist e depois também em Downloads. Importar a playlist inteira antes de apresentá-la; não buscar outras faixas da plataforma ao rolar. O limite já existente de 10.000 ocorrências por coleção continua explícito. Esta mudança não implementa novas plataformas de importação.

## Implementação

- Coleções carrega os metadados da coleção completa ao concluir a importação ou abrir uma coleção persistida. Downloads apresenta todos os registros da categoria e do filtro numa lista única. Os dois usam `ListView.builder` com extensão por linha: somente widgets próximos ao trecho visível são construídos. Barras framboesa permitem percorrer a lista; cabeçalhos ficam fixos. Setas/rodapé de página removidos.
- Busca, ordenação e filtros são aplicados no SQLite sobre toda a lista; seleção por Ctrl e seleção total continuam por ocorrência. Repetições preservadas. Arraste usa rolagem pela borda, sem troca de página. Faixas protegidas continuam fixas. Trocar coleção/busca/filtro/ordem retorna ao início; atualizações de status mantêm a rolagem. Edição de posição e abertura de revisão de download revelam a faixa solicitada.
- `ContinuousTrackListing` e `ContinuousDownloadListing` guardam metadados da lista, identificadores ordenados e revisões. Após o primeiro carregamento, somente registros alterados são relidos; a consulta dos identificadores mantém ordem e filtro globais. Não há releitura de todo o banco para cada atualização nem HTTP iniciado pelo scroll.
- Schema **13** acrescenta revisão por ocorrência e contador relacional, com triggers de inserção/alteração/exclusão, conclusão de arquivo e renomeação de coleção. A revisão interna não é ID/numeração editável. Dados anteriores começam com revisão zero e são preservados. As consultas são parametrizadas, com snapshot curto em isolate; rede/IO permanecem fora dos widgets.
- Tamanho/ausência de arquivo em Downloads é verificado somente para linhas construídas próximas ao viewport, com até 8 verificações simultâneas, janela máxima de 100 e cache de 30 segundos. Mudança de arquivo/status/conclusão invalida o cache. A decisão de baixar novamente sempre revalida o arquivo, sem depender desse cache.
- Downloads mantém limite defensivo explícito de 100.000 registros na lista única e 10.000 faixas por execução. Remover da fila processa seleção em lotes; não exclui playlist nem mídia. As consultas paginadas internas continuam nos fluxos de execução, conferência e histórico; elas não reaparecem como paginação na playlist ou Downloads.

## Design

Manter Manrope, fundo `#FAFAFC`, superfícies `#F3F4F6`, texto `#1E293B`, framboesa `#C9345B` e cabeçalho Downloads `#23273F`. Aproveitar a faixa liberada pela paginação para mais linhas. Não criar novo painel informativo, botão “carregar mais” ou lista global duplicada. Desktop/mobile compartilham lista, regras e identidade; confirmar gestos e leitura em larguras diferentes.

```text
Controles e busca
Cabeçalho fixo
Faixas / downloads da lista inteira  | barra contínua
                                    | sem páginas
```

## Validação e entrega

Versão incrementada após finalizar os dois fluxos para **0.1.41+42**, schema 13. Sem release/tag/push no ciclo local. Widgets mobile não comprovam execução nativa Android/iOS.

Testes novos verificaram 10.000 ocorrências persistidas, repetições, cache/deltas, consulta com 10.000 IDs, filtros e busca além das primeiras 40; 235 entradas simultâneas de Downloads, seleção de execução com mais de 100, alterações de conclusão/coleção e remoção da fila sem remover a coleção. Migração v12→v13 testada duas vezes, com integridade referencial e triggers mesmo com recursão habilitada.

Em 1100 e 390 px, as duas listas com 10.000 itens alcançaram diretamente o último: menos de 30 widgets construídos por viewport e menos de 60 IDs enviados à verificação de arquivo somando os dois extremos. O ensaio inicial encontrou custo de layout em Downloads ao saltar ao fim sem extensão fixa; a extensão por linha resolveu esse caso, e o ensaio final passou. Testes de widgets verificaram arraste com rolagem pelas bordas, Ctrl e estados de transferência nos layouts desktop e de toque.

As correções dos testes de migração removeram os triggers novos antes de reconstruir schemas antigos; os resultados de schemas legados não devem ser confundidos com dados migrados manualmente.

Validação final: `dart format`, `flutter analyze` sem problemas, **177 testes aprovados** e build Windows Release concluído. Inspeção visual de Coleções e Downloads em 1360 e 390 px, além dos testes de layout em 1920, 900 e 320 px. Essas verificações de widgets não constituem execução nativa Android/iOS.

Instalação local concluída e aplicativo aberto: **0.1.41**, incluindo registro do desinstalador e pacote `0.1.41+42`. Atalho aponta para o aplicativo instalado. Backup privado realizado antes da atualização; comparação após a migração confirmou todos os valores antigos preservados em coleções, faixas, histórico, preferências, candidatos, tentativas e grupos, com `quick_check=ok`. Motor musical preservado por SHA-256; binários e assets instalados conferidos com o pacote compilado. Evidências e dados locais não integram o commit.

Na janela Windows instalada, a playlist real de 232 faixas passou diretamente das faixas 39–44 à última (232); Downloads mostrou os 229 registros numa única rolagem até `undressed`, sem setas de página, com cabeçalho fixo e barra limitada ao corpo. Nenhum novo download foi iniciado. O app ficou aberto em Downloads, no início da lista. Sem publicação, tag ou push, conforme a pausa de releases solicitada.
