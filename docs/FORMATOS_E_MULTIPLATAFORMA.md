# Formatos e plataformas — Definitive Downloader

Requisito confirmado pelo usuário em 28/10/2026, com referência visual à lista de associações de arquivos de um instalador. A imagem identifica os formatos desejados; não define a interface do D.d nem comprova compatibilidade do aplicativo.

## Escopo confirmado

O Definitive Downloader é desktop **e** mobile. O piloto Windows atual é uma entrega parcial. Cada nova feature deve incluir regras compartilhadas, interação adaptada e execução validada nas plataformas de lançamento; o mobile não fica restrito a controlar downloads feitos no computador.

Além dos formatos tradicionais, o produto deve suportar os sete formatos abaixo nas duas famílias de dispositivos. Todos estão **planejados**, sem implementação ou validação no D.d nesta revisão.

| Formato solicitado | Extensão | Desktop | Mobile |
|---|---|---|---|
| JDownloader Link Container | `.dlc` | Planejado | Planejado |
| Cryptload Link Container | `.ccf` | Planejado | Planejado |
| RSD Link Container | `.rsdf` | Planejado | Planejado |
| Metalinks | `.metalink` | Planejado | Planejado |
| Meta4 Metalinks | `.meta4` | Planejado | Planejado |
| NewzBin Usenet Index file | `.nzb` | Planejado | Planejado |
| SFDL FTP Link Container | `.sfdl` | Planejado | Planejado |

A lista é adicional e não substitui os formatos tradicionais. O fluxo musical atual documenta importação CSV e geração de MP3/M3U8 no Windows; isso não valida os novos formatos nem seu funcionamento mobile. “Formatos tradicionais” não foi definido como uma lista fechada nesta solicitação; outras extensões devem ter requisitos e capacidades registrados antes de serem anunciadas.

## O que significa suportar um formato

O fluxo esperado é abrir/importar o arquivo, identificar e validar seu conteúdo, apresentar os itens para revisão, enfileirar a seleção e obter os arquivos por uma integração compatível. Reconhecer a extensão é apenas uma parte desse fluxo.

Registrar separadamente, por formato e plataforma:

- **Entrada:** seleção de arquivo no app e abertura/compartilhamento pelo sistema, conforme as integrações disponíveis.
- **Leitura:** variantes compreendidas, limites de tamanho e quantidade, conteúdo inválido e dependências necessárias para interpretar o arquivo.
- **Revisão:** itens identificados, ordem, ocorrências repetidas, destinos e pendências. Não iniciar downloads automaticamente ao abrir um arquivo.
- **Execução:** protocolos, serviços e autenticação necessários para obter os arquivos, com resultado e erro por item. Importar referências não comprova obtenção do conteúdo.
- **Saída:** arquivo salvo no dispositivo escolhido, integridade conferida e estado recuperável após interrupção.

A investigação de NZB deve incluir a obtenção via Usenet; a de SFDL deve incluir o fluxo FTP indicado na referência. Para os contêineres de links e Metalinks, validar tanto a interpretação quanto as fontes resultantes. Nenhuma dessas capacidades deve ser presumida a partir do motor musical existente. Variantes e especificações precisam de investigação técnica antes da implementação.

Associações de arquivos no desktop e registros de abertura/compartilhamento no mobile serão integrações próprias de cada sistema. A lista do instalador de referência não implica registrar associações agora nem copiar seu visual. A capacidade deve estar funcional antes de ser oferecida como associação suportada.

## Arquitetura e proteção dos dados

Manter contratos, regras de revisão e estados em Dart compartilhável, com leitores por formato e adaptadores de execução separados. Widgets não interpretam arquivos, acessam rede ou executam processos. O worker Python Windows atual não resolve a execução mobile; qualquer dependência adicional exige validação por plataforma.

Aplicar limites explícitos de entrada, itens, tempo de parsing e respostas. Arquivos malformados ou conteúdo incompatível devem produzir erro concreto sem bloquear a interface. Quando houver XML, impedir resolução de entidades externas e expansão sem limites. Não executar conteúdo do arquivo como código.

Validar esquemas e destinos antes de consultar a rede, sem encaminhar credenciais entre origens. Credenciais eventualmente contidas nos arquivos são sensíveis: não gravá-las em logs, evidências ou registros comuns do banco; usar o cofre quando for necessário guardar uma sessão. Não procurar credenciais existentes.

Usar registros relacionais por importação/item, preservar ordem e repetições, sanitizar nomes e conferir contenção na pasta de destino. Revisão, cancelamento, publicação de arquivos temporários e recuperação devem seguir os contratos da fila, sem marcar como concluído um arquivo não validado.

## Entrega e validação

Implementar uma feature por vez, preservando a prioridade do fluxo musical. Os sete formatos passam a ser requisitos do produto; esta revisão não determina uma ordem entre eles nem declara suporte disponível.

Para concluir cada formato, validar arquivos representativos e inválidos, variantes declaradas, limites, ordem e repetições, cancelamento, recuperação, segurança dos caminhos e obtenção de arquivos com integridade conferida. Separar testes locais de acessos reais a serviços e documentar os resultados exatos por plataforma.

Conferir a interface em larguras desktop e mobile, incluindo seleção de arquivo, revisão, erros e destino local. Um teste no Windows não valida mobile; controlar um executor no PC não comprova arquivo salvo no celular. Declarar dependências e lacunas explicitamente, mantendo a feature parcial enquanto houver plataformas de lançamento pendentes.

Esta alteração registra requisitos e critérios de entrega. Não altera código, instalador, associações do sistema ou versão publicada; não foi executado teste de compatibilidade com esses sete formatos.
