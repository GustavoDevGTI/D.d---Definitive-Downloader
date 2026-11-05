# Versão local 0.1.42 — espaço útil e cabeçalhos

Pedido de 04/11/2026, seguindo os quatro prints: remover a barra vertical duplicada em Coleções; retirar “Gerenciador de downloads”; alinhar pesquisa e comandos; mover o total de registros ao rodapé direito e aproveitar a altura liberada. Separar controles e colunas da playlist, alinhando a seleção total às caixas das linhas.

## Direção e implementação

Manter Manrope, fundo `#FAFAFC`, superfícies `#F3F4F6`, divisórias `#E5E7EB`, framboesa `#C9345B`, texto `#1E293B` e cabeçalho Downloads `#23273F`. A linha separa funções; não acrescentar decoração ou painéis.

```text
Downloads: comandos | filtros (se couberem) | busca
           filtros em linha própria nas larguras intermediárias
           tabela com mais altura
           seleção                         registros
Coleções:  comandos e pesquisa
           -----------------------------------------
           seleção e nomes das colunas alinhados às linhas
           faixas                       uma barra vertical
```

Na playlist, desativar somente a scrollbar automática do Flutter no corpo com barra própria, mantendo roda, arraste e rolagem contínua. Compensar os 3 px da borda lateral das linhas no cabeçalho; divisórias neutras acima e abaixo do cabeçalho. Em Downloads, pesquisa e comandos compartilham a linha a partir de 800 px úteis; filtros também entram nela a partir de 1380 px. Mobile mantém comandos acessíveis por rolagem horizontal e busca em linha própria. O total de registros fica no rodapé direito, abaixo da tabela, em todas as larguras.

Sem mudanças de dados, execução, fontes ou schema. Incremento local após finalizar os ajustes; releases continuam suspensas.

## Validação

`dart format` concluído; `flutter analyze` sem problemas e **177 testes aprovados**. Os testes de lista contínua agora usam explicitamente o tema desktop Windows, verificam ausência da scrollbar automática e alinhamento exato da seleção total com as caixas das linhas, mantendo alcance da última faixa em 10.000 itens. Os testes de layout conferem a busca na altura dos comandos e o total de registros abaixo da tabela, alinhado à direita.

Inspeção das imagens em 1920, 1360 e 390 px: Downloads sem título, contagem no rodapé e mais altura útil; controles, filtros e busca na mesma linha larga, com quebra intermediária dos filtros. Cabeçalho da playlist separado por divisória e seleção alinhada. Testes adicionais em 900 e 320 px passaram; widgets mobile não comprovam execução nativa Android/iOS.

Versão incrementada após os ajustes para **0.1.42+43**. Análise estática final e compilação Windows Release concluídas com essa identificação; a suíte aprovada não foi repetida apenas por essa troca de versão.

Instalação local concluída, registro do desinstalador em 0.1.42 e atalho da Área de Trabalho apontando para o app instalado. Backup privado anterior à atualização. Comparação dos dados após abrir confirmou todos os valores antigos preservados nas sete tabelas verificadas, schema 13 e `quick_check=ok`. Arquivos do pacote instalado conferidos por SHA-256, incluindo motor musical preservado. Evidências, banco e arquivos das contas não entram no commit.

Na janela Windows atualizada, confirmados seleção total alinhada, divisória do cabeçalho e uma única barra vertical framboesa na playlist, inclusive após rolar além da faixa 40. Downloads exibiu busca ao lado dos comandos, 229 registros no rodapé direito e tabela ampliada. Nenhum download iniciado. App deixado aberto em Downloads. Sem release, tag ou push.
