# Cota mensal do Worker `dd-playlists` — 26/11/2026

O Worker de importação pública do Spotify (`services/playlist-gateway`) passou a contar as chamadas RapidAPI no mesmo ciclo da assinatura. Antes, usava uma janela móvel de 31 dias com teto de 900. A pedido do usuário, o limite agora coincide com o plano BASIC: **1.000 chamadas por mês**.

## Regra

- O período começa no dia da assinatura, 12/11/2026, e se repete todo mês. Até o RapidAPI informar o horário próprio, a virada acontece às 00:00 UTC do dia 12. Em meses mais curtos, o dia é limitado ao último dia do mês.
- A resposta da primeira chamada de cada importação traz `x-ratelimit-requests-reset` (segundos até a renovação). O Worker grava esse instante em `quota_state` e passa a virar o período no mesmo horário do RapidAPI. Cabeçalhos ausentes ou inválidos são ignorados.
- O teto é exato: reservas que somariam mais de 1.000 no período são recusadas antes de chamar o provedor. A verificação de `x-ratelimit-requests-remaining` continua valendo e protege contra uso da chave fora do Worker.
- As reservas já existentes continuaram valendo: o período atual começou com 53 chamadas, igual ao painel do RapidAPI.
- Reservas de períodos anteriores ao período passado são apagadas. Nenhuma linha guarda IP, playlist ou chave.
- Configuração em `wrangler.jsonc`: `DD_QUOTA_LIMIT=1000` e `DD_QUOTA_ANCHOR=2026-11-12T00:00:00Z`. Ao trocar de plano ou de data de assinatura, ajuste esses valores e publique.

A regra fica em `quota-period.mjs`, independente do runtime. O Durable Object `RapidApiBudget` só fornece o SQLite e o relógio. O limite de subconsultas do Workers Free continua respeitado: metadados, duas reservas, uma observação da renovação e até 45 páginas somam 49 de 50.

## Verificação

- `node --test services/playlist-gateway/*.test.mjs`: 17 testes passaram e 1 foi pulado (o ensaio antigo do Trackhop, sem relação). Os testes novos usam `node:sqlite` com a mesma interface do Durable Object. Eles cobrem a virada no dia 12, meses curtos, a continuidade das 53 reservas, o teto exato, a âncora vinda do cabeçalho, entradas inválidas e a limpeza de linhas antigas.
- `wrangler deploy --dry-run` validou o pacote e as variáveis.
- Um Worker de teste local (`wrangler dev --local`, workerd) usou o `RapidApiBudget` real. O limite fechou em exatamente 1.000 (22×45 + 10), recusou a 1.001ª chamada e as reservas de 0 e 46, aceitou o cabeçalho válido e recusou o inválido. Esse ensaio não acessou o RapidAPI.
- Publicação em produção: versão `efb3002b-6d6d-49be-a1a1-403e065395bd`. `/health` respondeu 200, rotas desconhecidas 404 e o segredo `DD_RAPIDAPI_KEY` foi mantido.
- No Data Studio da Cloudflare, a tabela nova `quota_state` foi criada pelo código publicado. A consulta pelo período novo mostrou 53 usadas e 947 restantes, igual ao RapidAPI (5,30% de 1.000). Ainda não há âncora gravada: ela aparece na próxima importação real.

## Limitações

- O horário exato da renovação no RapidAPI só é conhecido depois da primeira importação com o cabeçalho de renovação. Até lá, o Worker vira às 00:00 UTC do dia 12. Nesse intervalo, a checagem do saldo informado pelo provedor impede que as páginas excedam a cota. Só a chamada de metadados é feita antes de conhecer esse saldo.
- Nenhuma importação real foi feita nesta etapa, para não gastar a franquia. O caminho completo com o provedor real será confirmado na próxima importação do app.
- O app Windows não muda: o endereço do serviço continua o mesmo.
