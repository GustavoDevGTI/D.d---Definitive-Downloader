# Definitive Downloader 0.1.33 — versão local

Identificação `0.1.33+34`, em 04/11/2026. Sem release/tag ou publicação remota.

## Concluídas e recuperação manual

Ao focar uma concluída, a aba inicial do painel é Informações. O usuário pode consultar Correspondência se desejar. A transição de uma faixa focada para Concluído também abre Informações, sem popup de sucesso. A consulta de fonte mostra provedor e URL da versão vinculada.

Apagar ou perder acesso ao arquivo fora do app não apaga histórico, não altera o registro em segundo plano nem agenda transferência. Ao selecionar a faixa e clicar em baixar, o app consulta somente os caminhos daquela seleção, em lotes paginados de até 40. Se uma concluída estiver indisponível, registra um pedido de recuperação, seleciona a primeira ocorrência para revisão e abre Correspondência, em Coleções. Em tela estreita, abre o painel modal; em desktop largo, usa o painel lateral. O botão iniciar em Downloads também aceita uma concluída cujo arquivo não está disponível e encaminha ao mesmo fluxo.

O primeiro clique não executa download. A versão anterior permanece identificada, com Usar fonte anterior como escolha explícita; o usuário também pode selecionar uma candidata ou informar outro link manual. A seleção da fonte somente deixa a faixa pronta. É necessário clicar novamente em baixar para transferir. Se houver seleção mista com recuperação pendente, nenhum outro trabalho daquela solicitação começa antes da revisão; outros pedidos indisponíveis permanecem identificados. O foco da revisão seleciona apenas aquela ocorrência na coleção, evitando baixar outras seleções antigas por acidente.

Se o arquivo ainda existir, não é baixado novamente. Se reaparecer depois da escolha da fonte, a próxima solicitação é bloqueada, preservando-o. Falha de acesso/disponibilidade não é apresentada como comprovação de exclusão física.

## Estado e segurança

Schema 11 acrescenta `tracks.redownload_state`, com valores vazio, review e approved. A migração inicializa a coluna vazia: não examina mídia nem cria pedidos automaticamente. Review e a ausência de aprovação sobrevivem ao reinício. Correspondência automática não substitui essa decisão; filtros, domínio, snapshot e reivindicação de trabalho excluem review. Fontes manuais anteriores continuam identificadas e nunca são silenciosamente reutilizadas.

Escolher uma candidata na recuperação permite substituir explicitamente o vínculo anterior daquela ocorrência e fixa a versão escolhida. Link manual só aprova quando a fonte explícita está pronta; metadados Spotify sem versão utilizável permanecem para revisão. Videoclipes continuam exigindo a autorização da versão conforme a política vigente. Recuperação aprovada não usa fallback automático para outra versão. Escutar/referências não foram implementados nesta versão.

ID, nome solicitado, posição e caminho anterior são preservados durante a revisão. A posição permanece fixa pelo vínculo com o arquivo anteriormente publicado. O arquivo indisponível não é apagado ou renomeado pelo app. A nova transferência usa as mesmas validações de áudio, capa e metadados. Apenas publicar o arquivo validado encerra a recuperação. Se o caminho final for o mesmo, o registro daquele arquivo mantém seu ID e recebe a nova data/fonte; se for diferente, o histórico anterior permanece e um novo arquivo é registrado. Não se trata de um histórico de eventos por tentativa.

Persistência, verificação e navegação são compartilhadas em Dart, com acesso ao disco fora dos widgets. O worker não foi alterado. Layout mobile exercitado em teste não comprova um motor musical nativo Android/iOS.

## Validação e instalação

- `dart format`: 111 arquivos, nenhum ajuste pendente. `flutter analyze`: nenhum problema. Suíte final completa: 140 testes aprovados.
- Ensaio de recuperação com o MP3 sintético local: primeira transferência cria arquivo; exclusão explícita da fixture e novo comando abrem review, sem outra chamada ao receptor; reinício mantém a exigência; escolha da fonte anterior só aprova; outro clique produz o arquivo validado novamente. Testes verificam bytes, posição, registro por caminho e nova data de conclusão.
- Cobertura de arquivo presente/reaparecido sem sobrescrita, seleção mista sem início parcial, link manual aprovado sem download, bloqueio de escolha automática/fallback, escolha explícita de candidata e migração v10 sem pedido automático. Nenhum novo download de provedor real nesta etapa.
- Widgets em 1360 e 390 px verificam Informações por padrão, encaminhamento do pedido para Correspondência e escolha da fonte sem disparar download; layouts inspecionados nas duas larguras. Os testes de fonte concluída anteriores foram ajustados para consultar Correspondência explicitamente.
- Build Windows concluído. Os 126 arquivos de lib/test/assets/pubspec/lock conferem com o staging. Worker musical preservado por SHA-256, sem mudanças de protocolo, motor ou dependências.
- Instalador local 0.1.33 gerado com SHA-256 registrado; aplicativo instalado `0.1.33+34`, registro Windows `0.1.33`, reaberto/respondendo e atalho conferido. Sem release/tag/publicação remota.
- Backup anterior preservado. Migração real local de schema 10 para 11 concluída, `quick_check=ok`; todas as colunas anteriores das tabelas verificadas mantiveram seus valores/hash após reabrir: 2 coleções, 242 faixas, 11 arquivos no histórico, 10 preferências, 2.183 candidatos, 11 tentativas e nenhum grupo. A nova coluna permaneceu vazia nas 242 ocorrências, sem pedido automático de recuperação. Nenhuma transferência ativa foi interrompida para instalar.
- Evidências privadas em `%LOCALAPPDATA%\DefinitiveDownloaderDev\local-version-0.1.33`, incluindo logs, layouts, backup e hashes. Não entram no repositório.
