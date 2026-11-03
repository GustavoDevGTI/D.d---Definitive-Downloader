# Definitive Downloader 0.1.15

Cores funcionais, feedback dos botões e maior compactação de Downloads, solicitados em 03/11/2026. Flutter `0.1.15+16`; instalador deriva a versão do pubspec.

- Iniciar usa verde `#326B5D`, já existente como cor funcional de sucesso; pausar usa âmbar `#91611A`; parar usa framboesa `#C9345B`; adicionar links usa azul-marinho `#23273F`. Utilitários usam azul acinzentado `#5B6B85`; remover mantém framboesa. A identidade e as cores oficiais das demais áreas são preservadas; o âmbar fica restrito à pausa.
- Botões habilitados reagem a hover/foco com preenchimento mais forte, ícone branco, contorno de 1,5 px. Pressionamento mantém o contraste da ação, sem sombras decorativas. Transição de 140 ms e cursor de ação; indisponíveis mantêm matiz atenuado, sem simular disponibilidade nem ação ao hover.
- O mesmo tratamento de Adicionar links aparece no ícone da coleção, barra/rodapé de Downloads e confirmação do diálogo. Barra continua em uma linha, com alvos de 48 px e rolagem horizontal no mobile.
- Limites mínimos: Nome e Salvar em 64 px; Servidor, Status, Tempo restante e Progresso 48 px; Tamanho, Velocidade e Baixado 40 px. Seleção permanece fixa em 40 px. Antes, os mínimos das colunas ajustáveis eram de 70–140 px. Larguras padrão, preferências salvas, máximo de 1200 px, restauração e ajuste por teclado permanecem.
- Cabeçalhos e valores usam uma linha com reticências nas colunas estreitas. Tooltips preservam nome completo, fonte, status/erro e caminho, além dos rótulos de cabeçalho. A revisão de compactação extrema levou à remoção de um recorte que ocultava parte das letras e caixas de seleção; a versão final mantém o desenho completo desses controles.

## Validação

`dart format`: 85 arquivos sem alterações; análise estática sem problemas; 86 testes Flutter aprovados na rodada final e build Windows release. O teste de arraste exercita largura abaixo do antigo mínimo; os layouts exercitam todas as colunas no mínimo, gravação/restauração das preferências e hover real por ponteiro. A mudança de cor do botão renderizado é verificada após o hover. Ícones brancos sobre as cinco cores funcionais têm contraste calculado de 5,09:1 a 14,65:1; controles inativos usam tonalidade atenuada. A revisão de hover levou à retirada da elevação, que causava recortes de pintura na tabela; o preenchimento e o contorno dão feedback sem esse efeito. Sem novos testes que apenas reproduzam os valores de estilo.

Capturas com fixtures em 1920×1080, 1360×820, 900×820, 900×600, 390×820 e 320×820; texto 1,3× no último. Revisão visual desktop/mobile, inclusive hover e compactação. Nenhum download de provedor ou autenticação foi realizado nesta revisão visual.

Sem migração do banco ou alteração de matching, fila, transferência, arquivos e contas. Motor musical da 0.1.14 preservado; o build Flutter não o substitui pelo staging antigo. Layout compartilhado com mobile validado por widgets; não houve build Android/iOS, e o motor nativo mobile permanece pendente.

## Instalação e distribuição

Atualização real com saída 0; aplicativo `0.1.15+16` aberto a partir da instalação local. Atalho da Área de Trabalho aponta para o executável instalado e o ícone oficial. Banco antes/depois: uma coleção, dez faixas, dez históricos, zero ativos, schema 9 e `quick_check=ok`. Backup SQLite local antes da atualização; nenhum dado de conta ou evidência foi publicado.

98 arquivos de fontes/testes/assets idênticos ao staging compilado. Executável, `data/app.so`, ICO e worker idênticos entre pacote e instalação por SHA-256. Worker preservado: `266B509F026A92827FA48E8335BF59865BB6B1B06552E56DB48276145D01D271`. ZIP verificado sem corrupção, sem banco, sessão ou transferência parcial. Logs e relatórios ficam no diretório local de evidências, fora do repositório. Layouts usam capturas de widgets; processo/versão/atalho foram conferidos separadamente, sem automação visual nativa.

[Release v0.1.15](https://github.com/GustavoDevGTI/D.d---Definitive-Downloader/releases/tag/v0.1.15), com instalador Windows x64, ZIP portátil e `SHA256SUMS.txt`. Releases anteriores preservadas; instalador sem assinatura digital.

| Artefato | Bytes | SHA-256 |
| --- | ---: | --- |
| Setup Windows x64 | 75.729.163 | `5f9ca56ad7b90e0b464adb4f990fd7eea833847a85774b99f75b291a11988c87` |
| ZIP Windows x64 | 99.525.924 | `3888965d7a729516a82c34f026e4d6216cefe7ee4a39a9ec4adb6fee3b540dcf` |
