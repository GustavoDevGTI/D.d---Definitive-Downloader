# Definitive Downloader 0.1.30 — versão local

Identificação `0.1.30+31`, em 04/11/2026. Ciclo local de feedback, sem release/tag ou publicação remota.

## Downloads

- Removido o popup que informava quantos arquivos foram salvos e a geração da M3U8. Falhas, interrupções, ausência de fonte e aprovação de videoclipes continuam comunicadas; a exportação M3U8 permanece funcionando.
- Nome usa título da música na primeira linha e artista na segunda, inclusive antes do download. A segunda linha mantém o artista visível quando o título é longo; tooltip apresenta ambos por completo e o caminho existente. Nome personalizado prevalece. Ordenação usa título/artista no SQLite antes da paginação, sem depender do nome físico do arquivo.
- Novos nomes físicos: `001 - Música - Artista [Provedor].mp3`, mantendo origem efetiva e proteção contra colisão. A legenda das próximas M3U8 também usa música antes do artista. Arquivos existentes não são renomeados, movidos ou regravados; seus vínculos permanecem válidos.
- Tamanho consulta o arquivo real concluído, em uma página de até 40 itens, com operações assíncronas fora dos widgets. Arquivo indisponível mantém o registro e não inventa tamanho. Durante o recebimento, usa o total informado pela origem; totais estimados são identificados por `≈`. Antes da resposta da fonte, o tamanho pode continuar desconhecido.
- Recebido mostra o volume efetivamente recebido na tentativa ativa. Nas concluídas, mostra os bytes do arquivo final disponível: capa/tags/transcodificação podem mudar esse valor em relação ao fluxo original. Tooltips distinguem essas duas fases; o volume histórico de rede não é reconstruído nem apresentado como medido.
- Velocidade e tempo restante são calculados com bytes reais e relógio monotônico. Sem total conhecido não há porcentagem/tempo inventados. Durante validação/capa/transcodificação, tempo mostra Processando, sem ETA. Na pausa, velocidade e ETA ficam sem valor, evitando exibir medições anteriores como atuais. A pausa continua limitando o item ativo e bloqueando novos itens, conforme contrato existente.
- Baixado em mantém data local e hora/minuto, sem segundos; a precisão persistida e a ordenação cronológica continuam intactas.

## Integração

`TransferProgress` e o medidor Dart são compartilhados; MP3 direto também envia medições. O adaptador Windows repassa eventos numéricos do worker a MusicDownloadService/DownloadService/LibraryController e à tabela. O worker Deezer/YouTube envia bytes, total conhecido/estimado e velocidade com limite de frequência de 500 ms, sem URL, requisição ou credencial. O evento final é enviado mesmo em arquivos rápidos. Cada nova tentativa, faixa ou fallback limpa as medições anteriores. Receber todos os bytes não comprova validação ou publicação do arquivo.

Não há migração de schema, mudança em fontes manuais, matching, autorização de versões, ordem/prioridade ou motor mobile. Os controles e cálculos compartilhados foram testados em layout estreito; isso não comprova execução Android/iOS nem fornece o motor musical nativo dessas plataformas.

## Validação e instalação

- `dart format`: 106 arquivos, nenhum ajuste pendente. `flutter analyze`: nenhum problema.
- Suíte completa: 126 testes aprovados. Após o ajuste visual de duas linhas, repetidos os 10 testes de tabela/medições; após padronizar a legenda M3U8, repetidos os 10 testes da fila. Todos passaram.
- 12 testes Python aprovados, incluindo frequência/contagem/velocidade do protocolo e hook YouTube simulado. Transporte MP3 testado em servidor HTTP local; testes de fontes usam fixtures, sem novo download de provedor real nesta versão.
- Layouts conferidos em 1360 e 390 px, incluindo título/artista, tamanho, velocidade, recebido e ETA. Testes verificam ausência de ETA sem total e durante pausa/processamento, data sem segundos e preservação do registro se o arquivo desaparecer.
- Build Windows final concluído, worker recompilado com telemetria numérica. Os 121 arquivos de lib/test/assets/pubspec/lock conferem com o staging; fontes Python de produção também conferem com o staging do worker. Diagnóstico health do worker compilado e instalado aprovado, sem conta ou requisição de mídia.
- Instalador final local gerado em `installer-final`, com SHA-256 registrado; aplicativo instalado `0.1.30+31`, registro Windows `0.1.30`, janela aberta/respondendo e atalho da Área de Trabalho apontando para o app instalado. Sem release/tag/publicação remota.
- Backup anterior preservado. Antes/depois da atualização e da reabertura: mesmos registros nas tabelas verificadas, 2 coleções, 242 faixas, 11 arquivos no histórico, 10 preferências, 2.183 candidatos, 11 tentativas e nenhum grupo. Schema 10 e `quick_check=ok`; nenhuma transferência ativa foi interrompida.
- Conferência de disco na biblioteca atual: 1 faixa concluída não oculta na página, arquivo disponível e tamanho consultável. Isto não revalida a decodificação do áudio nem testa o catálogo de um provedor.
- Evidências privadas em `%LOCALAPPDATA%\DefinitiveDownloaderDev\local-version-0.1.30`: logs, layouts, backup e hashes. Nenhuma evidência ou dado de conta é publicado no repositório.
