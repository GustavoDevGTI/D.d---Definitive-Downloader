# 0.1.95 — Limpeza visual e resposta dos controles

Entrega Windows 0.1.95+96, posteriormente consolidada para publicação com APKs Android a pedido do usuário em 23/11/2026. Nenhum emulador foi iniciado.

## Aplicação das duas skills solicitadas

Revisão leve do Início, dos formulários compartilhados de importação/captura e da resposta dos controles de Downloads, Coleções e Adicionar links. A direção é retirar decoração redundante e manter feedback curto, sem redesenhar a navegação ou alterar as regras musicais.

| Regra | Ajuste |
| --- | --- |
| U3/U4 | Retiradas as três descrições que repetiam os atalhos do Início e “Ver fila de mídias”. |
| U7 | Importação e captura de áudio mantêm seus rótulos visíveis, sem placeholders que os repetem. O exemplo de URL na captura de mídias continua por mostrar um formato. |
| U11/U21 | Retirados os pictogramas e as setas decorativas dos atalhos, além das setas das filas e dos arquivos recentes no Início. Os destinos e cliques são preservados. |
| U18 | Intervalo de 30 px no Início ajustado para o passo de 32 px. Mantidas as margens compartilhadas já definidas pelo projeto. |
| U20 | Hover/foco não ampliam mais os botões. A cor continua indicando interação, com transição de 150 ms. |

Animação: frequência de uso recorrente, propósito de feedback. Apenas pressionamentos por ponteiro usam escala 0,97, em 160 ms e curva `Cubic(.23, 1, .32, 1)`. A transição implícita é interrompível, sem mudar o espaço de layout. Foco e ativação por teclado conservam a geometria. Movimento reduzido e controles desabilitados não recebem transformação. Não foram adicionadas animações de entrada, contagem, rolagem ou movimento dos dados.

Tokens em `lib/app/motion.dart`, reutilizados pelo componente existente. Sem biblioteca adicional. Os ícones funcionais de download, pausa, parada, abrir/copiar referência, seleção e navegação de retorno continuam identificáveis. As cores das playlists, o azul do comando de download e os estados reais continuam presentes.

Os três indicadores da Visão geral permanecem como estão: uma eventual alteração da hierarquia entre eles exige avaliar qual informação deve ter prioridade, fora desta limpeza de superfície. Não se alterou persistência, busca, autenticação, fila ou arquivos pessoais.

## Validação

- `flutter analyze --no-pub`: sem problemas.
- Núcleo essencial + área `ui_common`, em uma rodada: 29 testes aprovados. Inclui hover sem alterar a geometria, clique, ativação por teclado, movimento reduzido, controle desabilitado, captura e listas contínuas.
- Prévia temporária do Início em Flutter com tema Windows: duas renderizações aprovadas e inspecionadas, em 1366×768 e 1024×600, sem overflow. Usa biblioteca isolada de fixture; não é ensaio de contas nem captura da janela nativa instalada.
- Compilação Windows Release e instalador concluídos. Aplicativo instalado e iniciado, com `ProductVersion` 0.1.95+96 conferida.
- Consolidação de publicação: cobertura offline concluída, com 281 testes Dart aprovados e 3 ignorados, reutilizando os casos aprovados do mesmo código. A matriz de layout ainda esperava a antiga ampliação no hover; foi atualizada para exigir geometria constante e conservar a verificação da mudança de cor. Dois casos de gestão/arraste tiveram timeout na execução paralela à compilação Android; os três arquivos afetados foram repetidos serialmente, com 11 testes aprovados, sem ampliar limites ou alterar as regras do aplicativo.
- Motor Python offline: 27 testes executados, 26 aprovados e 1 ignorado. Não representa novo ensaio de conta ou download real de plataforma.
- APKs ARM64 e x86_64 compilados, respectivamente com 68.734.551 e 71.972.861 bytes. Manifestos, versão 0.1.95/código 96, ABI, módulos nativos e assinaturas verificados. Certificados iguais aos da 0.1.94 publicada. Os três pacotes e o manifesto SHA-256 foram copiados e conferidos na pasta compartilhada.
- Publicação preparada com instalador Windows, dois APKs com assinatura de teste e `SHA256SUMS.txt`. Sem execução no emulador ou ensaios de provedores nesta consolidação.

As duas skills solicitadas foram instaladas globalmente no ambiente do usuário. Os scripts de prévia e imagens ficaram em diretório privado externo ao repositório; o script temporário foi arquivado fora do estágio de compilação após o uso.
