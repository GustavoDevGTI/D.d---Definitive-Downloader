# Ajustes locais de Músicas — 04/11/2026

Ciclo de feedback iniciado sobre a base 0.1.26+27, posteriormente identificado como 0.1.27+28 a pedido do usuário, sem tag ou release. Artefatos e commit da release publicada permanecem preservados. As mudanças de planejamento da biblioteca são distintas destes ajustes executáveis.

## Fluxo de correspondência

Importações reais iniciam automaticamente a conferência quando o motor está disponível. A lista abre enquanto a conferência prossegue, com progresso e interrupção. Abrir uma coleção ainda pendente retoma a busca das ocorrências sem fonte e sem revisão anterior. Não se inicia busca ao abrir uma coleção já conferida; fontes manuais, faixas concluídas e correspondências já vinculadas são preservadas na retomada automática. Exemplos locais não disparam provedores.

Resultado vazio, busca com erro e candidatos sem uma escolha automática segura ficam para revisão. O erro real continua associado à faixa. Videoclipes não são aceitos automaticamente. Uma busca interrompida conserva as correspondências já feitas e deixa as demais pendentes; não dispara download nem modifica a seleção do usuário. Importação parcial permanece identificada no resultado.

Rever correspondências continua como ação explícita no menu Mais ações da playlist. O usuário não depende desse menu para iniciar o fluxo normal após importar.

## Interface

Downloads, adição de links e acesso à fila passam para uma barra de ícones no topo da lista. Na correção posterior identificada como 0.1.27, confirmar, marcar revisão e informar/editar link ficam dentro de Conferência, abaixo da pesquisa e antes das candidatas, tanto no desktop como no mobile. Sem botões em formato de pílula empilhados no fim do painel. Busca de outras versões usa a ação no campo de busca. Cores e hover seguem os controles compartilhados de Downloads.

Faixas pendentes/de revisão têm fundo rosa suave na linha inteira, faixa lateral vinho, ícone de atenção e identificação Conferir. O foco visual é distinto do estado de revisão. Faixas concluídas mantêm consulta da fonte; a barra não desbloqueia sua edição.

## Busca, filtros e ordenação

Pesquisa por título/artista/nome de exibição usa comparação normalizada em Dart no SQLite, incluindo caixa e acentos comuns do português. Todas, Conferir, Prontas e Concluídas filtram antes da paginação. A caixa do cabeçalho seleciona o mesmo conjunto do filtro e da busca em todas as páginas.

Nome, Duração e Correspondência têm ordenação crescente/decrescente nos cabeçalhos; o menu Ordenar faixas oferece as mesmas escolhas em telas estreitas e permite voltar à ordem da playlist. Ordenação no SQLite antes do limite de página, com desempate por posição/ID. Duração ausente fica no fim em ambos os sentidos. Ordenar a visualização não altera a posição das ocorrências, a prioridade, os nomes dos arquivos ou a M3U8.

Não houve migração de schema nem implementação de reprodução nesta etapa. Referências e escuta das candidatas continuam no planejamento separado da biblioteca.

## Barra de rolagem de Downloads

Correção adicional solicitada durante o ciclo: a barra vertical terminava antes da parte inferior das linhas porque descontava a altura do cabeçalho em métricas que já correspondiam apenas ao corpo. A barra agora envolve somente a área das linhas, com o espaço horizontal separado. O cabeçalho permanece fixo na vertical e acompanha o deslocamento horizontal por controladores sincronizados, inclusive quando o foco traz uma coluna para a área visível, mantendo as divisórias alinhadas e a barra vertical na borda visível.

O teste de regressão reproduziu a ausência do trilho no fim em 1100 e 390 px antes da correção. Depois verifica alcance do trilho, arraste do indicador até o limite, visibilidade integral da última linha, alinhamento do cabeçalho e estabilidade da barra durante a rolagem horizontal.

## Validação

103 arquivos Dart formatados. Análise estática sem problemas. Suíte completa com 116 testes aprovada; após o ajuste final para suprimir a barra automática duplicada no desktop, os dez testes de tabela/rolagem foram executados novamente, incluindo tema Windows a 1100 e 390 px, todos aprovados. Análise e compilação Windows release repetidas para o código final.

Testes novos cobrem importação com conferência automática sem download, erros/resultados vazios/videoclipes para revisão, mais de uma página, preservação de fonte pronta, abertura de importação pendente e cancelamento. A conclusão assíncrona da conferência é aguardável e os ensaios aguardam também a finalização das consultas, sem apagar fixtures enquanto a tarefa ainda roda. Busca normalizada, seleção filtrada em 85 ocorrências e ordenação sem alterar posições verificadas no repositório. Integração de widgets exercita pesquisa, filtro, destaque e clique nos cabeçalhos, além das ações de aprovação e fonte manual.

Layouts a 1920×1080, 1360×820, 900×820, 900×600, 390×820 e 320×820 (texto 1,3× no último), com inspeção das capturas desktop/mobile. Testes sintéticos, sem novo ensaio de autenticação, download real ou reprodução. Não houve execução nativa Android/iOS nem automação visual nativa; validação de widgets e verificação do processo Windows são evidências distintas.

Atualização direta dos arquivos da instalação local, seguida de abertura do aplicativo e conferência do atalho. Backup anterior do SQLite, executável e app.so em diretório local privado. Antes/depois da atualização e após reabrir: schema 10, quick_check=ok, zero downloads ativos; preservação integral por hash de duas coleções, 242 ocorrências, dez históricos, dez preferências, 2183 candidatos, dez tentativas e zero grupos. Nenhuma sessão ou credencial inspecionada.

118 fontes/testes/assets iguais ao staging compilado; executável, app.so, flutter_windows.dll, ICO e worker iguais por SHA-256 entre o pacote local e a instalação. Motor preservado com SHA-256 266B509F026A92827FA48E8335BF59865BB6B1B06552E56DB48276145D01D271. Dados, backup e capturas reais mantidos fora do repositório. Esta primeira atualização foi validada sobre a base 0.1.26+27 e depois recebeu a identificação local 0.1.27+28, com mudanças ainda não publicadas; nenhuma tag, release ou asset publicado foi criado/substituído neste ciclo.
