# Definitive Downloader 0.1.105 — Windows e Android

O Android volta a ser publicado junto com o Windows: instalador x64 e APKs ARM64/x86_64 da mesma versão. Esta versão também traz duas mudanças na tela de playlists e corrige um pedido de conta Deezer que tinha sumido.

## Playlists

- **Carregamento visível ao importar.** Enquanto a playlist é lida, aparece uma barra animada abaixo dos botões de importação, com o andamento informado pelo app (por exemplo, quantas faixas já foram lidas). O botão passa a mostrar "Importando…", e o X continua cancelando. Vale também para a importação de arquivo e de pasta de áudio.
- **Clique na faixa separado da seleção.** Clicar na linha só abre a faixa em Informações. A caixa da linha muda apenas com um clique nela, pela caixa do cabeçalho (todas do filtro) ou com Ctrl + arraste. Antes, o clique simples deixava só aquela faixa marcada e desmarcava as outras, e o Ctrl+clique somava faixas à seleção. Essa regra da 0.1.29 foi substituída. Arrastar para reordenar continua igual, inclusive o arraste da seleção em bloco.

## Correção: conferência depois de adiar o Deezer

Quem escolhia **Deixar para mais tarde** no pedido de conta Deezer durante a importação e depois clicava em **Iniciar conferência** ficava sem resposta: nem pedido de conta, nem mensagem. Desde a 0.1.86, o botão manual passou a conferir só as faixas pendentes e, com isso, caiu na mesma regra que silencia as retomadas automáticas. Agora a conferência iniciada pela pessoa pede a conta Deezer de novo, só com a opção Cancelar. As retomadas automáticas continuam respeitando o adiamento durante a sessão. Afetava Windows e Android.

## Validação

- Análise estática sem problemas.
- Regressão Dart offline com os 59 arquivos de teste: 305 testes passaram e 4 opcionais foram ignorados. Na primeira rodada, 7 falharam. Seis eram do `layout_test`, que esperava a seleção pelo clique na linha, e foram ajustados para marcar pela caixa e conferir que abrir a faixa não altera a seleção. O sétimo, no `collection_manager_test`, estourou o tempo de espera de E/S sob carga. Repetidos no mesmo código, os 9 testes desses dois arquivos passaram.
- Um novo teste de regressão cobre a conferência pedida depois do adiamento. Ele falha sem a correção e passa com ela.
- Windows: o instalador 0.1.105 atualizou a instalação local (versão registrada 0.1.105, binário idêntico ao compilado), e o app abriu normalmente.
- Android, compilação: análise sem problemas e 47 testes Dart da área mobile aprovados. O script de build conferiu manifesto, ABIs, assinatura e bibliotecas dos dois APKs.
- Android, testes nativos no emulador dedicado (`Definitive_API_36`, API 36, sem contas reais), em duas etapas:
  - Bateria completa com o código da 0.1.104, que só difere desta versão nas três mudanças acima. Passaram smoke, fila, login web por fixture, captura de áudio, motor offline, segundo plano, exportação e destino SAF, e interrupção (três force-stops reais e quatro inícios de processo). O teste de pasta de áudio passou com o seletor do sistema conduzido por adb, usando uma pasta de fixture com dois WAV sintéticos.
  - Com o código da 0.1.105, os testes que montam o app completo: contas, smoke e fila passaram.
  - O teste de contas estava desatualizado desde a pausa do Android: procurava "Deixar para depois" e o antigo botão "Rever correspondências". Atualizado, ele mostrou o problema da conferência descrito acima e passou depois da correção, com dois MP3 sintéticos publicados, M3U8 ordenada e reprodução pelo MediaPlayer.
  - Os ensaios com provedores reais (`android_provider_test` e a parte SoundCloud real do motor) não foram executados e não contam como aprovação.
- Motor musical: mesmo binário e código da 0.1.103. Os 26 testes Python continuam valendo e não foram repetidos nesta máquina, que não tem o ambiente de testes do motor.

## Pacotes

Instalador Windows x64 e APKs Android ARM64 e x86_64, com assinatura de teste. As somas SHA-256 dos três pacotes estão em `SHA256SUMS.txt`.

O serviço de playlists (cota mensal de 1.000 chamadas, renovada no dia 12) é o mesmo da [0.1.104](RELEASE_0_1_104.md).
