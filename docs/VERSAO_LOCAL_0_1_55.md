# 0.1.55+56 — recuperação Android após interrupção

Checkpoint local de 06/11/2026, sem release/tag. Windows instalado permanece 0.1.48. Esta etapa aprofunda persistência do destino SAF; não encerra a paridade nem inicia testes humanos do APK.

## Alterações

- A reconciliação nativa reconhece uma renomeação pública já terminada mesmo quando o processo não conseguiu registrar a nova URI devolvida pelo provedor. Consulta nome final, tamanho e SHA-256 do diário antes de vincular o documento; não publica temporários nem inicia rede. Fonte, posição e revisão continuam sendo revalidadas pelo domínio compartilhado antes de concluir a ocorrência.
- A confirmação remove também o cache exato ainda registrado no staging quando a interrupção aconteceu antes de mover esse cache para a referência final. O documento público permanece autoritativo.
- Uma tentativa explicitamente retomada descarta somente o staging privado registrado da tentativa parcial anterior da mesma ocorrência/fonte. Valida UUID, contenção canônica, quantidade/profundidade e todos os descendentes antes de excluir; rejeita links simbólicos e áudio completo aguardando reaproveitamento. Não limpa pastas públicas, originais ou arquivos por prefixo.
- Recuperação e descarte privado ficam em `ManagedPublicationRecovery` e `ManagedPrivateWork`; a interface Flutter e o schema da biblioteca não mudaram.

## Automação focada

`tools/test_android_interruption.ps1` usa somente o AVD dedicado e o pacote `.integration`, preservando o aplicativo normal. O servidor HTTP e o áudio são fixtures locais, sem conta ou plataforma musical. Quatro processos separados verificam publicação, recebimento parcial, revisão persistida e reposição explícita. As fases encerradas por `am force-stop` devem terminar com erro do Flutter; o driver só as aceita após verificar o marcador, a contagem de rede e a ausência do processo. Elas não são contadas como testes Flutter aprovados.

```powershell
./tools/test_android_interruption.ps1 -WorkspaceRoot <estágio-local-identificado>
./tools/test_android_interruption.ps1 -WorkspaceRoot <estágio-local-identificado> -RenamedJournal
```

O segundo cenário regrava **apenas o diário do pacote isolado** para representar a janela após uma renomeação real, antes de registrar a URI retornada. Em seguida encerra/reabre o processo de verdade. Esse preparo determinístico não equivale a acertar o instante exato de uma morte do sistema durante a chamada nativa. O cenário também exercita as recusas de limpeza de link simbólico e MP3 completo, preservando um original fora do staging.

## Evidências

- Essencial + contratos de publicação/recuperação: **30 testes aprovados**, incluindo arquitetura, histórico, posições, reposição sem fallback e revisão sem aprovação automática. Análise estática sem problemas; sintaxe Python/PowerShell válida. Não foi executada regressão completa de provedores/contas.
- Cenário principal aprovado no pacote isolado: **três force-stops reais, quatro inicializações**, duas requisições para a faixa publicada/reposta e duas para a transferência parcial/repetida. Inicialização e aprovação da revisão não iniciaram rede. A primeira publicação foi reconhecida sem segunda obtenção; a tentativa parcial anterior foi retirada somente no retry explícito. Após exclusão externa, review persistiu, escolha ficou approved sem rede e outro comando repôs a mídia. Duas mídias públicas, M3U8 ordenada, histórico sem duplicação e ausência de cache completo/diários pendentes conferidos.
- Cenário de renomeação aprovado: publicação real seguida de preparo determinístico do diário `renaming` com URI temporária antiga e cache na pasta original; force-stop/reabertura reais. URI final/hash reconhecidos, conclusão/M3U8 reconciliadas, cache removido e **uma única requisição de áudio**. Recusas de limpeza de symlink e MP3 completo passaram; original fora do staging permaneceu intacto.
- A primeira tentativa foi bloqueada por aviso de ANR da **System UI do emulador**, antes da obtenção. Após recuperar a interface, o teste novo revelou uma expectativa incorreta: review usa status pending e conserva o histórico anterior, conforme o domínio existente. Corrigida a expectativa e incluída barreira explícita na automação antes do retry, o cenário completo passou. Essas tentativas não foram contadas como aprovadas.

## Limites

Os cenários usam Documents no emulador API 36. Cartão físico removido, armazenamento cheio, provedores em nuvem, encerramento em todas as janelas de M3U8/substituição e contas reais continuam no checklist. Nenhum fluxo de login ou catálogo foi revalidado por estas fixtures. A regressão completa fica reservada para suspeita concreta ou preparação de release.

## Artefato local

`dist/Android/Definitive-Downloader-0.1.55-Android-teste.apk`, SHA-256 `b0edac7b95725aaaae3fc951d895e44ac3aaa8980a86cca2ce170329976d2acc`. Assinatura debug v2 conferida, pacote normal `br.com.definitivedownloader.app`, versionCode 56/0.1.55, mínimo API 24/target 36, ARM64 e x86-64. Bundle do motor preservado por hash (`8886dc20e5c1fc07cd8b155dd0e1eae3c44cbcad3bd7db70a6a8812ca7226028`) e bibliotecas nativas verificadas no build. APK instalado por atualização no AVD dedicado, com dados preservados, e aberto; versões anteriores preservadas. Os testes funcionais precederam apenas a atualização dos números da versão; build final reutilizou esses resultados, sem repetir a matriz inteira. Sem release/tag e sem solicitar teste humano; Windows permanece 0.1.48.
