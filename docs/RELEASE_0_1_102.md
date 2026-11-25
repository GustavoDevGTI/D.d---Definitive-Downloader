# Definitive Downloader 0.1.102 — Windows

Corrige um bloqueio de interação ao reabrir playlists salvas com correspondências pendentes. A retomada automática da conferência acionava o estado global de ocupado: os cliques eram descartados, as caixas de seleção ficavam desabilitadas e até faixas já prontas não podiam iniciar download. Não era necessário haver corrupção ou migração inválida do banco para reproduzir esse comportamento.

## Correção

- Seleção por clique, checkbox, selecionar todas e Ctrl + arraste continuam disponíveis durante a conferência automática, inclusive pausada.
- Fontes já prontas podem baixar enquanto outras faixas aguardam a busca automática. A execução utiliza a seleção existente ao iniciar; músicas que ficam prontas depois não entram automaticamente nesse download.
- A reconferência completa conserva o bloqueio de início de download, pois pode revisar fontes já preparadas. Edição de nomes, fontes e posições conserva as proteções existentes.
- Não limpa seleção na inicialização, não apaga playlists, não redefine o banco e não renomeia arquivos já publicados. Não exige importar novamente a playlist.

## Reprodução e validação

O relato foi refinado para seleção presa, botões e músicas sem interação, sem mensagem de erro. O ensaio salva uma seleção em SQLite, reabre a biblioteca e mantém uma busca pendente por um sinal controlado. Antes da correção, três verificações falharam: clique descartado, checkbox desabilitado e faixa pronta impedida de baixar. Com a correção, o cenário permite trocar/deselecionar faixas, usar seleção total/Ctrl + arraste e pausar a conferência sem prender a seleção. Download usa somente um servidor HTTP loopback com MP3 de fixture; depois a busca é liberada e verifica-se que o arquivo concluído e as demais faixas são preservados.

Análise sem problemas. Resultado consolidado: **298 testes Dart aprovados** e **26 testes Python aprovados**, com 3 e 1 opcionais ignorados, respectivamente. A rodada geral aprovou 297 cenários; o único cenário restante foi repetido e aprovado após completar a duração na fixture nova (a ausência da duração corretamente exigia revisão). Os resultados dos cenários não afetados foram reaproveitados.

Não houve acesso ao banco ou ao PC da outra pessoa, login de plataforma ou emulador Android. A correção cobre o cenário reproduzido; outros comportamentos naquele computador exigem evidência própria.
