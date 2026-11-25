# 0.1.98 — Retorno persistente nas abas de Músicas

Windows 0.1.98+99. A seta **Voltar às coleções** era fornecida pelo workspace da playlist somente à barra da aba Coleções; as barras de Capturar áudio e Downloads eram construídas sem essa ação.

A navegação de Músicas agora conserva o retorno fornecido pela playlist enquanto ela está aberta. A seta aparece também em Capturar áudio e Downloads. Ao acioná-la nessas abas, fecha o detalhe da playlist e volta à lista de coleções; o retorno é então limpo. Sem uma playlist aberta, não cria uma seta sem destino.

Não altera fila, busca musical, seleção ou reprodução. O teste existente de navegação passou a percorrer as duas abas, verificar a seta, retornar à lista e reabrir a playlist antes de continuar os contratos do player.

## Validação

Análise sem problemas. Núcleo essencial e teste focado de navegação: 23 testes aprovados. O percurso Capturar áudio/Downloads → seta → lista de coleções → reabrir playlist foi validado em 1360, 900 e 390 px, conservando os contratos de reprodução do teste existente.

Compilação e instalador Windows concluídos. Versão 0.1.98+99 instalada e iniciada; instalador copiado ao compartilhamento e validado por SHA-256 `4f30471b50776b4d72ed081e109eabdbc2365e4ff8264e9ab732e9012188a03a`. Sem emulador, APK ou publicação nesta etapa.
