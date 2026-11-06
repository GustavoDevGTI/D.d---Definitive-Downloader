# 0.1.51+52 — fila Android e posições com lacunas

Entrega local Android de 06/11/2026, sem release/tag. Windows instalado permanece 0.1.48. Motor e ensaios de SoundCloud/YouTube Music da 0.1.50 são conservados; não foram repetidos nesta correção de biblioteca/fila.

## Mudança

Excluir/substituir uma duplicata pode deixar uma posição vazia antes de uma mídia concluída. O arraste tentava recompor números contíguos e recusava o movimento dos pendentes por deslocar indiretamente a concluída. Agora permuta apenas os slots existentes, incluindo as lacunas, e atualiza a execução nos mesmos slots. IDs, mídias, fontes e posições concluídas não mudam. O número retornado pelo movimento corresponde ao slot real.

O editor também confundia contagem de faixas com maior número: uma playlist com números 2, 3 e 4 tinha três itens, mas não permitia salvar o nome da faixa 4. A validação transacional usa o maior número real; a apresentação valida o inteiro positivo e deixa o limite atual para a transação. Não há SQL/IO no widget. Nomes/IDs continuam bloqueados depois do início dos downloads.

## Verificações focadas

- Duas regressões novas reproduziram os bloqueios antes das correções: arraste com concluída fixa após exclusão e renomear um número acima da contagem. Depois, o arquivo de edição e as interações em 900/390 px passaram (17 testes). Essencial final: 19 testes passaram. Focados de duplicatas, recuperação e fila passaram; não foi rodada regressão completa.
- Emulador Android 16/API 36, pacote `.integration`, SQLite real e DownloadService real, com catálogo sintético e servidor HTTP loopback de fixture. Isso não é download de plataforma. Recebimento de 65.244 bytes, pausa/retomada da transferência, permuta de pendentes, link extra recebido e baixado na mesma execução, quatro conclusões e M3U8 com quatro entradas. Duração lida pelo leitor Android.
- Reposição após excluir somente a mídia do teste: primeiro clique pede revisão; aprovar a fonte não inicia trabalho; novo clique obtém o arquivo, preservando ocorrência, número e caminho.
- Popup real de duplicatas por toque, Usar a nova versão e Fazer para todos: mídia antiga escolhida foi excluída, a outra mídia preservou bytes/posição 2 e o novo lote ficou nas posições 3/4. Reordenar pendentes conservou a lacuna e a concluída; diário ficou vazio.
- O primeiro ensaio de HTTP esperava progresso entre blocos pequenos que podiam ser agrupados no dispositivo; a fixture passou a transmitir blocos contínuos antes da barreira. Seu teardown agora aguarda o Future da execução, incluindo refresh, antes de remover o banco temporário. Repetiu-se somente esse caso. O teste do editor procurava o rótulo incorreto “Salvar”; seletor corrigido para “Salvar alterações”, sem mudança de texto no produto.

Editor por toque passou no emulador: playlist com três itens e maior número 4, nome alterado, posição 4 preservada e zero downloads iniciados. Análise Flutter sem problemas. Evidências ficam em armazenamento local de desenvolvimento, fora do Git.

## Pacote final

APK local debug, `br.com.definitivedownloader.app`, versionCode 52/versão 0.1.51, mínimo API 24/target 36, ARM64/x86-64. Assinatura v2 verificada, runtimes nativos conferidos pelo build e cópia em Downloads com o mesmo hash. SHA-256: `33fc8029d12165ee353f7b7b9e9e7778914a6cc00f592882083a782667ebe3c2`. Mantidos os artefatos anteriores 0.1.49/0.1.50, sem sobrescrevê-los.

## Próximos blocos

Continuam no [checklist](ANDROID_PARIDADE_CHECKLIST.md): autenticação Spotify com callback Android, sessão/arquivo Deezer reais, playlists públicas por origem, armazenamento público/SD e compartilhamento, notificações/serviços de download e áudio em segundo plano, gestos/tabelas grandes e aparelho físico. Nenhuma dessas capacidades é declarada concluída por estes ensaios de fila.

Reprodução focada, no estágio Android preparado: `./tools/test_android.ps1 -TestFile integration_test/android_queue_test.dart`. Usa somente seu banco/pasta temporários, nenhum dado da biblioteca principal, sem contas. `-PlainName` permite repetir apenas um cenário; não repetir todos os testes reais de fontes.
