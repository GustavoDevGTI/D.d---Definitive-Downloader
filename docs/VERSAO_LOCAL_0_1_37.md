# Versão local 0.1.37 — limites das áreas

Pedido posterior do usuário em 04/11/2026, com três prints: player sob a lateral, versão deslocada para cima e barra de rolagem junto ao cabeçalho. Corrigir esses limites antes de continuar a importação de playlists Deezer. Nenhum código de importação novo faz parte desta versão.

## Ajustes

- O player pertence à coluna interna de Músicas. A barra lateral passa a ocupar toda a altura disponível e mantém navegação/versão fora do player. No desktop, a borda esquerda do player coincide com a borda direita da lateral; no mobile, continua acima da navegação inferior.
- A versão permanece na base esquerda da lateral, com 16 px de respiro inferior, sem subir quando o player aparece. Preservar comportamento de pausa e fila ao sair de Músicas.
- A área rolável de Downloads é recortada abaixo do cabeçalho fixo. A barra vertical possui 8 px de respiro nas extremidades do corpo, preservando o preenchimento azul de toda a largura do cabeçalho e a sincronia horizontal das colunas.

Plano visual: manter Manrope, navegação `#23273F`, acento `#C9345B`, hover `#A01F45`, superfícies `#F3F4F6` e fundo `#FAFAFC`. Nenhuma mudança decorativa ou novo controle. Alinhar os limites por responsabilidade:

```text
Lateral       | Conteúdo e tabela
              | Cabeçalho fixo
              | Corpo com rolagem própria
Versão        | Player somente em Músicas
```

Schema 12 e arquivos físicos preservados. Sem release/tag/push durante o ciclo local. Interface e limites compartilhados em Flutter; a execução nativa mobile segue sem validação própria.

## Validação

- `dart format lib test`: 142 arquivos, sem ajustes pendentes.
- `flutter analyze --no-pub`: sem apontamentos no staging local.
- `flutter test --no-pub`: **172 testes aprovados**. Limites do player e versão verificados em 1360, 900 e 390 px; barra vertical, cabeçalho fixo, ajuste de colunas e última linha em 1100 e 390 px. A suíte completa também cobre layouts em 1920, 1360, 900, 390 e 320 px.
- A verificação de pixels confirma a barra framboesa somente abaixo do cabeçalho e dentro das margens do corpo. Capturas de 1100 e 390 px inspecionadas. O teste antigo de alcance foi ajustado para iniciar a interação dentro do novo limite de 8 px; o arraste até o fim permanece validado.
- Versão incrementada após os ajustes: **0.1.37+38**, schema 12 sem migração.

Compilação Windows release concluída. Pacote comparado com 157 arquivos de fontes/assets/testes do staging; worker musical congelado preservado. Installer local com SHA-256, EXE **0.1.37+38**, registro **0.1.37** e atalho para a instalação conferidos. Sem release/tag/push.

Backup anterior à atualização preservado. Comparativo integral do SQLite, antes/depois da instalação e da navegação, confirmou schema 12, `quick_check=ok` e os mesmos dados: 2 coleções, 242 ocorrências, 11 registros de arquivos, 10 preferências, 2183 candidatos, 11 tentativas e 0 grupos. Nenhuma mídia movida/excluída, playlist real alterada ou download iniciado neste ajuste.

Conferência nativa em janela 1366 px: player começa após a lateral e a versão permanece na base ao entrar em Músicas/Downloads. Cabeçalho azul permanece imóvel ao rolar; barra vertical inteiramente no corpo, com separação visível do cabeçalho. Aplicativo deixado aberto em Downloads. Evidências privadas em `%LOCALAPPDATA%/DefinitiveDownloaderDev/local-version-0.1.37`.

Importação Deezer permanece como próxima etapa, sem novo botão ou capacidade anunciada neste ajuste.
