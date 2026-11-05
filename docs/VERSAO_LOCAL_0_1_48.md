# Capas, escuta, busca e seleção — 0.1.48 local

Pedido de 05/11/2026, vinculado às quatro capturas do usuário. Sem release/tag/push durante o ciclo local.

## Comportamento

1. **Capas ao navegar/selecionar/rolar:** a leitura de capa incorporada passou a uma função estática, evitando capturar o estado não serializável do cache ao entrar em isolate. Capas já carregadas ficam disponíveis sincronamente ao remontar a miniatura, evitando o quadro vazio ao voltar na lista. Falhas transitórias têm espera de cinco segundos e permitem outra tentativa, em vez de serem guardadas como ausência definitiva. Linhas têm identidade por ocorrência e a miniatura não reutiliza a imagem anterior quando muda de referência. Cache mantém os limites anteriores (100 entradas / 12 MiB, quatro leituras simultâneas).
2. **Ouvir alinhado:** escuta, abrir/copiar referência e usar versão compartilham altura de 36 px e alinhamento vertical central, com hit area consistente e quebra de linha a partir da esquerda. O grupo permanece no lugar já existente em Informações e nas candidatas, sem novas caixas/avisos permanentes.
3. **Ouvir significa áudio interno:** retirar Ouvir no YouTube Music/YouTube/SoundCloud quando só existe referência externa. As fontes sem reprodução interna conservam Abrir referência e Copiar link; não há abertura automática do navegador por uma tentativa de Ouvir. Downloads locais continuam prioritários, inclusive para essas origens; Deezer pode oferecer Ouvir prévia, identificada como trecho. Escutar não confirma fonte ou inicia download. Falha de reprodução informa indisponibilidade e não abre outro app.
4. **Buscar a faixa específica antes de alternativas:** consultar as três fontes implementadas (Deezer, YouTube Music e SoundCloud). Sem resultado com título/artista correspondentes, fazer rodada dirigida ao título e artista pedidos, começando pelo SoundCloud. Se encontrar a música específica, filtrar títulos alheios antes de apresentá-los. Revalidar duração/versão/explicitude e autorização pelo matcher existente; buscar videoclipes continua último recurso e exige aprovação. Não anunciar como motor serviços apenas discutidos ou suportados pelo TuneMyMusic. Consultas e resultados continuam limitados, canceláveis, sem cookies/credenciais novas.
5. **Ctrl + arraste:** em Coleções e Downloads, selecionar aditivamente todas as linhas atravessadas para cima/baixo, preservando seleções anteriores. Nas bordas, rolar e continuar selecionando. Usar a ordem exibida (inclusive filtro/ordenação), sem alterar numeração/prioridade/arquivos. O cabeçalho fica fora do alvo. Sem Ctrl, o arraste normal da playlist continua reordenando e obedecendo às proteções existentes. O gesto é de mouse/teclado; seleção por checkbox/toque continua disponível no mobile. Não habilitar edição/seleção musical durante operações que já a bloqueavam.

## Estrutura e validação proporcional

`CtrlDragSelection` compartilha o gesto entre as tabelas; cada controlador recebe IDs e conserva sua própria seleção. Atualizações SQLite em lotes ficam no repositório, não no widget nem em closure do controlador enviada ao isolate. Escritas da seleção por varredura são serializadas. Downloads agrupa a notificação dos IDs selecionados. Nenhuma migração; schema continua 16. Worker e dependências permanecem inalterados.

Testes focados reproduzem: capa incorporada em MP3 sintético, falha de rede seguida de retry, remontagem com cache sem quadro vazio e troca de referência sem capa antiga; alinhamento dos controles e ausência de play externo; busca dirigida SoundCloud com exclusão de outro título; seleção nos dois sentidos e em borda nas duas tabelas, preservação da ordem e arraste normal. Layouts afetados em 900/390 px; tabelas em 1100/390 px, com lista virtualizada e cabeçalho fixo.

Aplicada a política proporcional: núcleo essencial de 19 contratos e arquivos focados afetados; sem executar toda a regressão. Rodada final do runner com núcleo + casos que tiveram interferência de flags: **32 aprovados, um optativo ignorado**. Outros contratos focados de gestos, capas, player e matching passaram nas rodadas da alteração; não somar rodadas repetidas como testes distintos. Não houve novo ensaio de download real de provedor.

Durante a validação foi corrigido o runner PowerShell: apagar explicitamente as variáveis optativas do ambiente evita que valores vazios sejam interpretados pelo Dart como flags presentes. Flags são restauradas ao final. Não tratar falha de caminho vazio dos testes optativos como defeito de provedor. As novas suítes específicas foram classificadas no manifesto.

Evidências privadas em `%LOCALAPPDATA%/DefinitiveDownloaderDev/local-version-0.1.48`; fontes, fixtures, testes e documentação no Git. A UI adaptativa compartilhada foi testada; não foi executado dispositivo Android/iOS nativo.

## Entrega local

`0.1.48+49` no pubspec e 0.1.48 no rodapé/instalador. Análise estática final sem problemas; Windows Release compilado reutilizando os testes focados, sem rodar regressão no build. Conferidos 193 arquivos de fontes/testes/assets contra o staging; SHA-256 do worker preservado. Instalador e SHA256SUMS privados. Instalação sobre o app existente terminou com código zero e oito hashes essenciais correspondem ao pacote; atalho instalado preservado.

Janela nativa 1366 px: abrir Músicas → coleção Teste, descer até as últimas faixas e voltar ao início; capas apareceram e permaneceram nas ocorrências corretas. Selecionar a primeira faixa mostrou a capa em Informações e Ouvir alinhado com abrir/copiar referência. Seleção anterior restaurada e app deixado em Coleções, sem reprodução, download, mudança de fonte, nova importação ou alteração de ordem. A seleção com Ctrl + arraste foi exercitada nos testes de widget das duas tabelas, não anunciada como gesto nativo ensaiado nesta janela.

Comparação do banco antes/depois da instalação e após essa conferência: duas coleções, 242 faixas, 12 históricos; todos os valores anteriores preservados (exceto revisão transitória de lista, omitida do comparador), schema 16 e `quick_check=ok`. Backup anterior preservado. Sem release, tag ou push.
