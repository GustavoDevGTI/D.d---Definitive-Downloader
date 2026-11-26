# Definitive Downloader 0.1.104 — Windows

A cota do serviço de importação de playlists Spotify passa a seguir o ciclo mensal do RapidAPI. Antes, o serviço contava as chamadas numa janela móvel de 31 dias, com teto de 900, e cada chamada voltava ao saldo só 31 dias depois de feita. Agora o limite é o do plano: **1.000 chamadas por mês, renovadas todo dia 12**, junto com a assinatura.

## Cota mensal do serviço de playlists

- O período começa no dia da assinatura e zera inteiro na virada, no mesmo horário informado pelo RapidAPI (`x-ratelimit-requests-reset`). Até esse horário ser conhecido, a virada acontece às 00:00 UTC do dia 12.
- O teto é exato: uma importação que ultrapassaria 1.000 chamadas no mês é recusada antes de chamar o provedor. A checagem do saldo informado pelo RapidAPI continua ativa.
- As chamadas já feitas no mês continuam contando. No momento da publicação eram 53 de 1.000, igual ao painel do RapidAPI.
- O limite e a data ficam configurados no serviço. Uma troca de plano não exige nova versão do app.

O serviço foi publicado na Cloudflare antes desta versão e já atende a 0.1.103 e as anteriores, pois o endereço é o mesmo. Esta versão registra a mudança no histórico e entrega o instalador correspondente. O aplicativo em si não muda: além do número de versão, o código Dart é o mesmo da 0.1.103.

Detalhes técnicos e verificação do serviço: [GATEWAY_COTA_MENSAL.md](GATEWAY_COTA_MENSAL.md).

## Validação

- Serviço: 17 testes Node passaram e 1 foi pulado (o ensaio antigo do Trackhop). O runtime local da Cloudflare (workerd) fechou o limite em exatamente 1.000. A produção respondeu ao `/health`, e o contador publicado coincide com o RapidAPI. Nenhuma importação real foi feita, para não gastar a franquia.
- Aplicativo: análise estática sem problemas. Na regressão Dart offline, **303 testes passaram** e 4 opcionais foram ignorados. Dois testes de interface (`redownload_test` a 390 px e `track_interaction_test` a 900 px) estouraram o tempo de espera de E/S durante a primeira rodada, que ocorreu junto com a compilação do instalador. Repetidos isoladamente no mesmo código, os dois arquivos passaram (11/11).
- Instalação: o instalador 0.1.104 atualizou a instalação local (versão registrada 0.1.104, binário idêntico ao compilado, atalho do Menu Iniciar mantido), e o app abriu normalmente.
- Motor musical: é o mesmo binário da 0.1.103 (SHA-256 `18f17dee…`), e seu código não mudou. Os 26 testes Python da 0.1.103 continuam valendo e não foram repetidos nesta máquina, que está sem o ambiente de testes do motor.
- Android pausado: sem APK e sem emulador nesta publicação.
