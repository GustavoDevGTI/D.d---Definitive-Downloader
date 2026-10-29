# Ferramentas de playlists — escopo do Definitive Downloader

Atualizado em 27/10/2026, a partir das cinco opções da imagem enviada pelo usuário. Todas entram no planejamento do produto, com identidade visual própria e implementação incremental. Este documento amplia o escopo; não indica que as funções já estejam disponíveis no executável.

## Funções previstas

| Opção no Definitive Downloader | Resultado esperado | Primeira entrega proposta |
| --- | --- | --- |
| **Transferir** | Recriar playlists em outra conta/plataforma, com correspondência por gravação, ordem e relatório de ausências. | Uma origem e um destino efetivamente validados, conforme o [estudo de transferência](TRANSFERENCIA_DE_PLAYLISTS.md). |
| **Compartilhar** | Entregar uma playlist a outra pessoa, com opções para abrir as gravações em serviços diferentes e importar uma cópia. | Exportação de arquivo e links oficiais das plataformas. Depois, página compartilhável com endereço próprio, controle de publicação e revogação. |
| **Cópia de segurança** | Preservar playlists, metadados, ordem e repetições, permitindo restaurar a coleção local e preparar nova transferência. | Arquivo versionado de backup local, com verificação e restauração testada. CSV para interoperabilidade; arquivos de mídia locais como opção separada. |
| **Gerar playlist com IA** | Montar uma seleção a partir de um pedido, por exemplo “rock brasileiro dos anos 2000 para uma viagem, com 40 faixas”. | Rascunho revisável com faixas verificadas no catálogo escolhido, duração aproximada, restrições e motivos da seleção. Salvar localmente antes de oferecer publicação. |
| **Organizar** | Identificar duplicatas, editar nome/descrição, ordenar, filtrar, dividir ou combinar playlists e aplicar ações em lote. | Diagnóstico e prévia das alterações na coleção local; o usuário escolhe o que aplicar. Escrita remota vem após validar a integração correspondente. |

**Download** continua sendo um módulo do produto. Transferir, compartilhar, fazer backup ou gerar uma playlist não concede automaticamente acesso a arquivos de áudio completos. A escolha de baixar passa pelo fluxo de fontes e formatos já previsto.

## Comportamentos que precisam ser preservados

### Compartilhar

- Permitir escolher a playlist e os dados publicados. Não incluir conta, tokens, caminhos locais ou histórico privado no material compartilhado.
- Manter referência à plataforma e gravação original. Links para outras plataformas são correspondências verificadas; ausências e versões alternativas ficam visíveis.
- Começar com uma cópia estática. Alterações futuras e colaboração são recursos posteriores, não consequências implícitas de compartilhar.
- Um link hospedado pelo Definitive Downloader exige infraestrutura pública própria. Guardar localmente a playlist ou criar um endereço aleatório não torna esse link acessível a outras pessoas.
- Antes de publicar, apresentar uma prévia do conteúdo e da visibilidade. Revogar um link encerra o acesso hospedado, mas não desfaz cópias já exportadas pelos destinatários.

### Cópia de segurança

- Separar **backup de playlists** de **cópia dos arquivos de mídia locais**. O primeiro guarda a organização e referências; não promete conter o áudio do catálogo de streaming.
- Preservar nome, descrição, ordem, ocorrências repetidas, IDs das plataformas, metadados e correspondências disponíveis, com data e versão do formato.
- Usar exportação consistente dos registros relacionais em um pacote versionado, com manifesto pequeno e verificação de integridade. Não guardar toda a biblioteca em um JSON ou carregar o pacote inteiro em memória.
- Não copiar o banco aberto de forma ingênua nem incluir credenciais. Quando a mídia local for incluída, processá-la por arquivo e validar referências relativas.
- Restaurar em área temporária, validar formato, limites e caminhos e apresentar o que será incorporado antes de alterar a biblioteca existente.
- Diferenciar restaurar a coleção local de recriar playlists em contas externas. A segunda operação reutiliza transferência, permissões e conferência de disponibilidade atual.
- Não apresentar backup como concluído antes de verificar integridade. A entrega precisa demonstrar restauração de ordem e repetições, além de lidar com pacote corrompido.

### Gerar playlist com IA

- Interpretar o pedido em critérios: estilos, período, artistas, quantidade, duração, idioma, exclusões e versões, quando informados.
- Consultar o catálogo e montar um rascunho com IDs verificáveis. A IA pode sugerir nomes para busca; o resultado de linguagem, sozinho, não comprova que uma faixa existe no serviço.
- Mostrar itens não encontrados e substituições propostas. Permitir fixar faixas, remover sugestões e refazer somente a parte não aprovada.
- Publicar ou baixar somente após revisão, através dos módulos de transferência ou download. Não dar ao modelo acesso direto para modificar contas.
- Declarar se o processamento é local ou externo. Antes de transmitir dados, informar o provedor e o conteúdo enviado; uma descrição do pedido não autoriza enviar toda a biblioteca ou o histórico de audição.
- Provedor, custo, limites e forma de execução ainda serão definidos. Não simular integração de IA com uma lista fixa de demonstração.

### Organizar

- Classificar possíveis duplicatas: mesma gravação/ID, mesma gravação em outro lançamento ou título parecido de gravações diferentes. Nome igual, sozinho, não basta.
- Preservar repetições intencionais. O usuário escolhe a política e as ocorrências a remover; nenhuma deduplicação automática no fluxo de importação ou transferência.
- Antes de aplicar um lote, mostrar adições, exclusões e mudanças de posição. Permitir selecionar um subconjunto.
- Guardar um estado anterior consistente para alterações locais. Para operações remotas, explicar as possibilidades reais de recuperação e registrar o que o provedor confirmou.
- Não tratar indisponibilidade de rede como faixa ausente. Reordenar e limpar uma coleção remota depende das capacidades e permissões daquele destino.

## Interface e arquitetura

As cinco funções compartilham a biblioteca e o motor de correspondência. Cada uma terá módulo, estado e histórico próprios, com persistência relacional paginada. As funções previstas não devem ser concentradas no `LibraryController` atual.

| Módulo | Responsabilidade |
| --- | --- |
| `transfers` | Preparar e executar cópia em uma plataforma de destino. |
| `sharing` | Preparar conteúdo publicável, exportação compartilhável e integração com eventual hospedagem. |
| `backups` | Criar, verificar e restaurar pacotes locais. |
| `playlist_generation` | Interpretar critérios e produzir rascunho validado contra catálogo. |
| `organization` | Diagnosticar e preparar alterações revisáveis em playlists. |

Esses nomes descrevem a organização futura. Criar os módulos quando houver implementação correspondente, evitando arquivos vazios e abstrações sem uso.

No desktop, propor um menu discreto **Ferramentas** com as cinco entradas e ações contextuais na playlist selecionada. A função em uso ocupa a área principal; a lista de músicas permanece central. Não adicionar cinco cartões grandes, ícones em bolhas ou gradientes do site de referência.

No mobile, apresentar as mesmas funções e regras em navegação adequada à tela, compartilhando Dart e separando apenas integrações de sistema. Cada entrega deve informar quais plataformas foram realmente validadas. Windows é o alvo atualmente entregue; mobile permanece pendente.

## Sequência proposta

1. **Transferir:** concluir uma cópia remota pequena, verificável, com correspondência e recuperação de falhas.
2. **Organizar:** revisão de duplicatas e ações locais em lote, aproveitando o mesmo modelo de ocorrências.
3. **Cópia de segurança:** exportação consistente e restauração comprovada. A proteção do estado anterior acompanha desde o início as alterações em lote do organizador.
4. **Compartilhar:** começar com arquivo/links; acrescentar link próprio quando a hospedagem estiver definida.
5. **Gerar playlist com IA:** implementar após catálogo, revisão e gravação estarem confiáveis e o provedor ter sido escolhido.

A ordem é uma recomendação técnica, não uma aprovação para publicar dados, contratar serviços ou conectar contas nesta etapa. As cinco opções estão incluídas no escopo solicitado; implementar uma feature por vez continua sendo a diretriz do produto.
