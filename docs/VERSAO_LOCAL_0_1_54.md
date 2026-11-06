# 0.1.54+55 — destino público Android integrado

Checkpoint local de 06/11/2026. Sem release/tag; instalação Windows permanece 0.1.48. A paridade completa ainda está em andamento e os testes humanos continuam adiados.

## Destino e publicação

- Escolher pasta oferece armazenamento pertencente ao app e **Pasta pública ou cartão SD** pelo seletor SAF. O retorno concede leitura/escrita persistentes para a árvore escolhida, sem permissão ampla de armazenamento. Os rótulos mostram o destino público nas configurações, tabela, informações e histórico.
- O motor continua recebendo somente uma pasta regular privada. Depois da obtenção, o MP3 é inspecionado, copiado por ContentResolver para documento temporário e conferido por tamanho/SHA-256 antes da publicação do nome. Nenhuma URI `content://` é passada para File, processo Python ou argumento de shell.
- O banco nativo `managed-documents.sqlite3` separa destinos, pastas, trabalhos, vínculos de mídia e remoções. O banco compartilhado da biblioteca continua no schema 16. A migração nativa 1→2 acrescenta apenas a habilitação/revogação de destino. URI e referência privada de identidade são distintas: o caminho conservado pela biblioteca identifica o vínculo; não comprova presença de um arquivo regular.
- A conclusão SQLite ocorre depois da publicação pública. Ao confirmar, o cache completo é eliminado; disponibilidade, tamanho, reprodução, capa e tags consultam a mídia pública. Portanto, apagar a mídia pelo gerenciador não é mascarado por uma cópia privada. Pastas públicas sobrevivem à desinstalação; pastas pertencentes ao app continuam sendo removidas pelo Android.
- Se o destino falhar, o áudio validado permanece em staging. Nova tentativa para a mesma ocorrência/fonte reaproveita esses bytes, sem consultar novamente a plataforma. A falha de armazenamento não entra no fallback nem registra um provedor como indisponível. Uma faixa pendente reordenada ajusta numeração/tags temporárias sem obter o áudio novamente, conservando as posições concluídas.
- A M3U8 é publicada na pasta correspondente, com nomes relativos iguais aos documentos. Sua substituição prepara/verifica a nova versão e só remove o documento anterior registrado quando o hash continua igual. Arquivo público desconhecido ou alterado fora do app é preservado; não há exclusão por prefixo ou limpeza recursiva do destino.

## Biblioteca e recuperação

- Player MediaPlayer abre a URI exata do documento público. MediaMetadataRetriever lê tags/capa dessa mesma versão; a imagem não depende de manter o MP3 completo no armazenamento privado.
- MP3 importado pelo seletor/Compartilhar segue o mesmo destino escolhido: original intocado, cópia pública numerada, conclusão local e M3U8. Falha antes do commit desfaz somente as cópias registradas do lote. A revisão de duplicatas continua no domínio compartilhado.
- Substituição de versão registra a remoção pública exata junto ao diário relacional existente. O documento antigo só é excluído após o commit que remove sua ocorrência. Cancelamento/restauração conserva a publicação anterior; remoção verifica exclusividade, identidade e hash. Outras faixas/posições e originais importados não são alterados.
- Reconciliação ao iniciar só finaliza uma publicação já validada da fonte e posição atuais ou trata o diário da operação autorizada. Não inicia downloads, não publica staging incompleto, não aprova revisão/reposição e não elimina histórico independente. Confirmação pendente de uma conclusão já registrada conserva a data/hora original do histórico. Renomear/publicar em um provedor documental não é uma transação SQLite: estados intermediários são conservados para reconciliação/repetição explícita.
- **Revogar acesso**, nas configurações da pasta, exige confirmação e conserva documentos e vínculos. O app nega acesso imediatamente e libera a concessão persistente; uma permissão temporária ainda mantida pelo Android não permite contornar a revogação no app. Selecionar novamente a mesma árvore restaura o vínculo. Falta de permissão não é tratada como exclusão do arquivo nem aprova um novo download.
- Arquivo removido fora do app mantém o registro concluído. Baixar solicita revisão; escolher fonte não inicia obtenção. Somente outro clique em Baixar realiza a reposição, com ID/posição conservados e sem fallback automático.

## Verificações executadas

- Essencial + publicação/plataforma/composição/duplicatas/player: **63 testes passaram e um ensaio opcional foi ignorado**. Inclui arquitetura sem ciclos, contratos de arquivos/duplicatas, preservação de originais e retomada/reordenação de publicação sem segunda obtenção. Não é regressão completa nem novo ensaio dos catálogos.
- Depois da reconciliação e do controle de acesso, **sete testes focados passaram**: publicação/reordenação, concluir somente a fonte atual sem aprovar revisão, canal Android e confirmação de revogação no layout de celular.
- Análise estática final sem problemas. Os dois testes de publicação/recuperação passaram novamente após acrescentar proteção para posição divergente e conservação da data de conclusão. Scripts PowerShell/Python analisados sintaticamente. Regra de espaço/SD removido não é substituída por essas fixtures.
- Emulador dedicado API 36 x86-64, pacote `.integration`, sem conta/biblioteca pessoal: seletor SAF real em Documents; servidor HTTP loopback de fixture; pasta pública indisponível após seleção causou falha; restaurar o destino permitiu repetir só a escrita, com **uma única requisição de áudio**.
- Após concluir, nenhum MP3 completo ficou no cache; disponibilidade/tamanho, capa/tags e MediaPlayer pela URI pública passaram. Apagar externamente o MP3 foi detectado. Primeiro clique abriu review, escolha manual ficou approved sem rede e novo clique obteve a segunda cópia. ID/posição preservados.
- Importação de MP3 produziu documento público e manteve o original byte a byte. Revogar acesso impediu consulta sem transformar isso em arquivo excluído/review; selecionar a mesma pasta restabeleceu acesso. Substituir a primeira faixa removeu seu documento público e manteve a importada na posição 2; a nova entrada ficou na posição 3, sem iniciar download. M3U8 e diário final foram conferidos. Cenário nativo final passou em 38 segundos.
- O teste inicial identificou uma comparação rígida de caminhos canônicos antes da obtenção. O adaptador passou a comparar a contenção relativa ao diretório canônico registrado, conservando a rejeição de redirecionamentos/`..`. O caso passou após a correção. Uma tentativa separada perdeu a descoberta do VM Service antes de iniciar o cenário; não foi contada como teste funcional aprovado.
- Rodada nativa final com código da 0.1.54: cenário repetido após ajustes de reconciliação/revogação, aprovado em 37 segundos. Não repetidas as suítes inteiras de contas, provedores ou interface sem relação com armazenamento.

Rodada focada no estágio local identificado:

```powershell
./tools/test_android_storage.ps1 -Scenario Destination
```

Usa o mesmo AVD `Definitive_API_36`, intents e seletor reais, e remove somente sua pasta UUID de fixture. Não repetir plataformas/contas sem mudança correspondente.

## Limites ainda abertos

O ensaio comprova o provedor local Documents do emulador. **Não** comprova cartão SD físico removido, provedor em nuvem, pouco espaço real, todos os fabricantes, morte do processo em cada janela de renomeação nem sessão Deezer/Spotify real. Persistência das permissões e reconciliação estão implementadas, mas esses cenários nativos ainda precisam de evidência própria no checklist. A exportação independente da 0.1.53 continua disponível para pastas privadas; o destino público primário desta versão é uma função diferente.

Referências primárias: [diretórios/permissões SAF](https://developer.android.com/training/data-storage/shared/documents-files), [identidade/renomeação de DocumentsContract](https://developer.android.com/reference/android/provider/DocumentsContract) e [MediaPlayer com URI](https://developer.android.com/reference/android/media/MediaPlayer). Não foi incorporada extração nova nem utilizada credencial Windows.

## Artefato local

`dist/Android/Definitive-Downloader-0.1.54-Android-teste.apk`, SHA-256 `33334d9dc60882b9a476c3a3d031d4ffd048edaea3e762a120f378e0b464de44`. Build debug ARM64/x86-64 com bibliotecas nativas e bundle do motor conferidos por hash; assinatura v2 verificada. Atualização instalada preservando dados no AVD dedicado e aberta: pacote `br.com.definitivedownloader.app`, versionCode 55/0.1.54, mínimo API 24/target 36. Versões anteriores preservadas. Sem release/tag e sem solicitar teste humano do APK; Windows permanece 0.1.48.
