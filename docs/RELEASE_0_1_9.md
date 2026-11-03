# Definitive Downloader 0.1.9

Revisão de textos solicitada em 03/11/2026 para reduzir poluição visual. Flutter `0.1.9+10`; versão do instalador derivada do pubspec.

## Mudanças

- Removido o painel informativo de Conferência abaixo das coleções, que parecia um botão. A conferência funcional continua disponível ao abrir uma coleção e selecionar a linha de uma faixa.
- Removidas a orientação repetida do Início, a introdução de Configurações e as explicações de cabeçalho/rodapé do histórico em Arquivos.
- Downloads sem o rodapé explicando regras de provedores. Velocidade e tempo restante mantêm `—` quando indisponíveis; a limitação aparece no tooltip do cabeçalho correspondente.
- Captura sem parágrafo introdutório, filtro estático ou painel vazio sobre resultados futuros. Um único aviso informa que a captura de links está indisponível; o botão continua desabilitado.
- Conferência sem instruções permanentes sobre checkbox ou exclusão de videoclipes. Sem faixa selecionada, exibe apenas “Selecione uma faixa”. Identificação da fonte, duração, versão, erros e controles continuam presentes.
- Rótulos, tooltips dos ícones, estados vazios essenciais, avisos de funções indisponíveis e informações de decisões nos diálogos foram preservados. A versão da sidebar deixa de repetir “Desktop e mobile”; o escopo do produto permanece multiplataforma.

A preferência do usuário passa a constar em `AGENTS.md`: rótulos claros e ajuda contextual, evitando blocos estáticos de orientação. Nenhuma alteração de paleta, logo ou funções; widgets compartilhados atendem desktop e mobile.

## Validação

- `dart format --output=none --set-exit-if-changed lib test tools/export_brand_assets_test.dart`: 70 arquivos, sem diferenças.
- `flutter analyze --no-pub`: sem problemas. `flutter test --no-pub`: 67 testes aprovados. Testes existentes de captura e navegação foram adaptados aos textos removidos, mantendo verificações de controles, espaçamento e navegação.
- Layouts a 1920×1080, 1360×820, 900×820, 900×600, 390×820 e 320×820; texto 1,3× no último. Coleções, Captura e Downloads revisados visualmente em 1360 e 320 px. Capturas `docs/images/clarity-019-*` usam fixtures isoladas, sem downloads reais.
- Build Windows release `0.1.9+10` compilado. Fontes, testes, assets, lockfile e ícone correspondem à cópia compilada; dependências preservadas.
- Inno Setup compilado, instalador de 75684460 bytes. ZIP portátil validado sem corrupção; ambos têm SHA-256 em `SHA256SUMS.txt`. Instalador sem assinatura digital; FFmpeg e licenças preservados.
- Atualização real instalada com saída 0. Processo `0.1.9+10` aberto em `%LOCALAPPDATA%/Programs/Definitive Downloader`; atalho da Área de Trabalho aponta para a instalação e o ícone da marca. Nenhum instalador colocado na Área de Trabalho.
- Executável, `data/app.so`, ICO e worker têm hashes iguais no pacote, em `dist` e na instalação. Worker preservado: SHA-256 `EFD3B3C8B74030F4A1336120EEC80995CBF7511E49B01B692A1AB6A8D86F19C7`.
- Banco antes/depois: uma coleção, dez faixas, dez registros de histórico, zero downloads ativos, schema 7 e `quick_check=ok`. Credenciais e cookies não foram inspecionados. Evidências locais em `docs/evidencias/clarity-019-*`, fora do controle de versão.

A revisão visual foi feita em capturas de widgets. Versão, processo e atalho da instalação foram conferidos separadamente; não houve automação visual nativa nesta rodada.

Sem mudanças no banco, contas, regras de matching ou motor musical. Não houve novo ensaio real de provedores. Layout mobile em widgets não equivale a build Android/iOS ou obtenção nativa mobile.

## Distribuição

[Release v0.1.9](https://github.com/GustavoDevGTI/D.d---Definitive-Downloader/releases/tag/v0.1.9), com instalador Windows x64, ZIP portátil e SHA-256. Versões anteriores preservadas; dados e evidências locais de contas não entram na publicação.
