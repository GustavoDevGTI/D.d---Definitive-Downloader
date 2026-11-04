# Definitive Downloader 0.1.29 — versão local

Identificação `0.1.29+30`, em 04/11/2026. Sem tag, publicação remota ou release.

## Interação com faixas

Removidos os três pontos de cada faixa. Clique direito abre o menu com Editar faixa, reutilizando o formulário de nome, posição e link/ID. F2 também edita a faixa focada. Nas telas mobile, Informações da conferência oferece edição como alternativa ao clique direito; a ação fica indisponível quando a regra de bloqueio se aplica.

Clique simples seleciona uma faixa e substitui a seleção anterior somente na coleção atual. Ctrl+clique (ou Command em dispositivos compatíveis) alterna aquela ocorrência sem limpar as demais, inclusive em outras páginas. As caixas de seleção continuam disponíveis. Fundo e caixa identificam a seleção; foco e destaque de revisão permanecem distintos. Ctrl+clique não abre o painel modal compacto a cada seleção.

No desktop, clicar, segurar e arrastar permite mudar a posição da faixa. Em telas de toque, segurar por 280 ms inicia o arraste, permitindo continuar usando o gesto comum para rolar. O indicador vinho mostra inserção antes/depois da faixa de destino. Soltar atualiza a ordem real e a numeração contínua; não altera a chave SQLite, o ID da plataforma, o nome ou a fonte. Ao arrastar uma faixa pertencente a uma seleção múltipla, todas as ocorrências selecionadas da coleção são movidas como um bloco, preservando a ordem interna e as repetições.

As bordas da lista fazem rolagem durante o arraste. Segurar sobre a seta de página por 650 ms troca a página e permite soltar sobre uma faixa do novo trecho; não é necessário carregar todas as faixas para renderizar. Soltar fora dos destinos cancela a ação. Soltar sobre uma faixa do próprio grupo não reordena o grupo. Depois de um movimento, a visualização usa a ordem da playlist; busca/filtro continuam aplicados.

Movimento persistido em transação, limitado a 10.000 ocorrências da coleção. Apenas IDs, posições e seleção são consultados para o lote. Numeração temporária negativa evita colisão da restrição de posição; falha reverte o lote. A primeira transferência continua bloqueando nomes e ordem, inclusive por arraste e após reinício. O estado é reconferido no SQLite junto da operação, evitando contornar o bloqueio pela interface ou por uma corrida com a fila. Nenhum arquivo é movido ou renomeado, nenhuma repetição é removida e nenhum download é iniciado pelos gestos.

## Validação e instalação

- `dart format`: arquivos formatados; `flutter analyze`: nenhum problema.
- Suíte completa: 122 testes aprovados. Após ajustar o gesto nativo de mouse/toque, os dois testes de interação foram repetidos e passaram em 900 px (Windows) e 390 px (Android); análise novamente sem problemas.
- Cobertura de seleção simples/Ctrl entre páginas, edição por clique direito, arraste individual e em grupo, renumeração, repetições, persistência após reabrir o banco, troca de página durante o arraste, cancelamento e bloqueio após transferência. Testes usam bancos temporários, sem provedores reais.
- Layouts inspecionados em 1360 e 390 px. Isto valida o layout e os gestos em teste; não comprova execução nativa Android/iOS.
- Build Windows final concluído. Os 119 arquivos de fonte/testes/assets e configuração conferem com o staging utilizado; motor musical validado por SHA-256 e preservado da 0.1.26.
- Pacote local e instalador 0.1.29 gerados. Aplicativo instalado atualizado para `0.1.29+30`, reaberto e atalho da Área de Trabalho conferido. Sem release, tag ou publicação remota.
- Backup SQLite e executável anterior preservados antes da instalação. Comparação antes/depois da atualização e da reabertura confirmou todos os registros idênticos: 2 coleções, 242 faixas, 10 arquivos no histórico, 10 preferências, 2.183 candidatos e 10 tentativas. Schema 10, `quick_check=ok` e nenhuma transferência em andamento.
- Evidências privadas em `%LOCALAPPDATA%\DefinitiveDownloaderDev\local-version-0.1.29`, incluindo logs, layouts, backup e hashes do pacote/instalador. Esses arquivos não entram no repositório.
