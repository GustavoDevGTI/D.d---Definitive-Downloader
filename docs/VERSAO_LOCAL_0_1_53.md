# 0.1.53+54 — compartilhamento recebido e cópia pública no Android

Checkpoint de paridade, 06/11/2026. Sem release/tag; Windows instalado permanece 0.1.48. Testes humanos continuam adiados até implementar todas as funções desktop operacionais no mobile.

## Receber sem importar automaticamente

- Android aceita `SEND` de texto/áudio e `SEND_MULTIPLE` de áudio. Um link pode vir acompanhado do título colocado pelo outro app; o formulário extrai os endereços e os validadores existentes conferem cada fonte. Repetições continuam presentes para decisão de duplicatas.
- `AndroidShareInbox` pertence ao processo, com banco relacional separado: lotes e arquivos em linhas, sem playlist serializada. Até oito recebimentos, 32.768 caracteres, 100 MP3 por lote, 200 MiB por arquivo e 1 GiB de mídia pendente. O recebimento não confirma correspondência nem inicia download.
- Documentos são lidos com ContentResolver e copiados para área privada limitada. `content://` nunca é usado como caminho de File; não se solicita acesso geral aos arquivos do aparelho. O mesmo módulo de cópia serve ao seletor e ao compartilhamento. O importador valida o MP3 e cria sua cópia numerada na playlist, conservando original/tags.
- Revisão permite escolher uma coleção ou criar uma nova, editar os links recebidos, adicionar ou cancelar. Usa os controles/importadores/decisões de duplicatas já existentes; extras de links continuam pelo mesmo controlador da execução. Operações incompatíveis e outros diálogos aguardam antes de mostrar a revisão.
- Encerrar a revisão libera apenas a cópia temporária daquele lote. Caixa pendente sobrevive no armazenamento privado; um recebimento interrompido vira erro explícito. Morte do processo entre commit da importação e confirmação de consumo ainda exige cenário próprio para reconciliar recebimentos, sem alegar execução exatamente uma vez.
- Navegação implícita de deep links do Flutter desativada: intents de documentos passam exclusivamente pela caixa de entrada revisável. Isso corrige o conflito encontrado pelo teste real de SEND com data URI.

## Pastas, compartilhamento e exportação

- Pasta principal/Abrir localização agora abre um navegador das pastas de mídia pertencentes ao app. Lista, sobe um nível, abre ou compartilha arquivo com FileProvider e concessão temporária de leitura. Nenhum caminho privado cru é entregue ao outro aplicativo.
- Exportar cópia abre o seletor oficial SAF. O destino pode ser uma pasta oferecida pelo provedor do Android, inclusive SD quando disponível. Cria uma subpasta nova com identificador próprio, sem sobrescrever arquivos do destino, e copia MP3/M3U8 mantendo a estrutura relativa. Limites: 10.000 arquivos, 10 GiB, profundidade oito e 12.000 entradas visitadas; sem links simbólicos ou arquivos de controle/staging.
- Escrita e leitura de conferência ocorrem fora da UI. Cada arquivo é verificado por tamanho e SHA-256; nomes devolvidos pelo provedor e referências da M3U8 são conferidos antes de sucesso. Cancelamento não muda a biblioteca.
- Diário SQLite nativo registra a raiz e cada documento criado. Limpeza verifica o conteúdo de todas as pastas antes de excluir os documentos exatos registrados, depois somente diretórios vazios. Conteúdo desconhecido, SD indisponível ou acesso revogado impedem limpeza e conservam o diário. Nunca excluir por prefixo nem assumir que ausência de acesso significa pasta vazia. Recuperação é serializada entre instâncias da Activity.
- Permissão persistente é usada para a operação/recuperação e liberada ao terminar sem pendências. Não há permissão ampla de armazenamento. A cópia exportada é independente: mudanças posteriores na playlist não a atualizam ou removem.

**Limite importante:** o destino principal das transferências ainda é uma pasta pertencente ao app, removida ao desinstalar. Esta versão implementa exportação explícita, não um destino SAF direto nem espelhamento automático. Destino direto exige mapeamento/publicação/recuperação por documento e integração consistente com player, histórico, substituição e arquivo ausente; continua no checklist. SD físico, remoção/revogação e provedores de terceiros não estão validados por um ensaio em Documents.

Próximo bloco de armazenamento: separar o arquivo regular temporário que o motor valida da referência documental publicada; registrar destino/URI/tamanho/hash e estado de publicação relacionalmente. Player, disponibilidade, histórico e substituição devem consultar a referência publicada, sem considerar um cache privado como prova de que a mídia pública ainda existe. Falha de publicação conserva o áudio validado para repetir só a escrita, nunca dispara novo download/fallback ou aprovação de recuperação. Não implementar isso substituindo caminhos por strings `content://` nos tipos atuais.

## Verificações focadas

- Essencial + recebimento/plataforma/composição: 28 testes passaram. Cancelar conserva biblioteca; adicionar MP3 em nova playlist cria cópia idêntica e não inicia download. Composição desktop/390 px continua funcionando.
- Rodada Android automatizada no pacote isolado `.integration`: SEND de texto real, cancelar; SEND de MP3 real com concessão de leitura, revisar/adicionar, validar ordem/arquivo e exportar pelo DocumentsUI. Cópia pública verificada por SHA-256 e M3U8 relativa. Os dados são fixtures sem conta/biblioteca pessoal.
- O teste detectou e corrigiu a preparação truncada de MP3 por `adb shell content write`: a automação agora usa push exclusivamente do arquivo UUID de fixture e confere o áudio lido pela URI antes de enviar. Não houve afrouxamento da validação do importador para aceitar o arquivo truncado.
- Cenário adicional nativo: diário relacional semeado exclusivamente na instalação `.integration`, com uma cópia registrada e uma sentinela pública não registrada. A primeira tentativa recusou a limpeza antes de excluir qualquer arquivo. Depois de a automação remover sua própria sentinela, a segunda recuperou somente a cópia registrada/pasta vazia e exportou normalmente; diário final vazio. Isso valida a regra de propriedade, não simula encerramento real do processo nem SD removido.
- Após ajustar o limite acumulado de cópias e tornar persistente o aviso de caixa cheia, recebimento/plataforma passaram em mais sete testes focados. Rodada nativa final passou novamente, incluindo nove intents consecutivos: aviso de excedente, oito lotes preservados/consumidos e nenhuma importação automática. O cenário de diário também passou; tabelas do diário terminaram vazias.
- Análise estática final sem problemas, scripts conferidos pelos parsers PowerShell/Python. Uma rodada perdeu o VM Service antes de iniciar o teste; o runner de armazenamento agora encerra apenas o processo `.integration` anterior antes de rodar, preservando os dados. Repetição focada passou em 45 segundos de cenário. Não repetidos ensaios de plataformas/contas/motor sem alteração, nem regressão completa.

Para repetir apenas a integração afetada no estágio local: `./tools/test_android_storage.ps1`. Reutiliza o AVD dedicado `Definitive_API_36`; o acompanhante envia intents e opera o seletor usando hierarquia atual. Só cria/remove suas próprias fixtures e o pacote de testes. Evidências ficam fora do Git.

Referências primárias consultadas: [documentos, diretórios e permissões SAF](https://developer.android.com/training/data-storage/shared/documents-files) e [compartilhar arquivos com concessão de leitura](https://developer.android.com/training/secure-file-sharing/share-file). Não são promessas de reprodução integral ou de disponibilidade de catálogo.

## Pacote local

`dist/Android/Definitive-Downloader-0.1.53-Android-teste.apk`, SHA-256 `3f1020512fd94aae932e89f49473850bb12f6ada768e307d171a952e89110117`. Build debug local, assinatura v2 verificada, ARM64/x86-64, mínimo API 24/target 36, com pacote nativo/módulos por hash conferidos. Instalado com atualização preservando dados no AVD dedicado; metadados confirmam pacote `br.com.definitivedownloader.app`, versionCode 54/0.1.53. Artefatos anteriores preservados. Sem release/tag e sem disponibilizar rodada de testes humanos; não substitui a instalação Windows.
