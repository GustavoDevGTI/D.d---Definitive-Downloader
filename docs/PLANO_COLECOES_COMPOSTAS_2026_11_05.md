# Coleções compostas e MP3 local

Pedido de 05/11/2026; executar todo o conjunto antes de incrementar/instalar a próxima versão local. Releases continuam suspensas.

## Etapas vinculadas às capturas

1. **Print 1 — cadeado:** retirar o controle visual da playlist; preservar as regras de proteção das faixas iniciadas/concluídas.
2. **Prints 2 e 3 — grupos:** retirar a linha “Grupos” e mover Novo grupo para os ícones de cada playlist. Resposta explícita do usuário: criar o grupo por esse ícone também inclui a playlist nele. Preservar filtros/renomear/remover grupo com acesso contextual compacto.
3. **Prints 4 e 5 — Nova playlist:** criar vazia quando só há nome/grupo; acrescentar campo de link opcional. Com link, ler/importar a playlist completa para a nova coleção, usando o nome escolhido. Falha não deixa coleção vazia involuntária ou importação parcial anunciada como completa.
4. **Print 6 — Adicionar links:** aceitar um lote misto de faixas individuais e playlists completas das fontes já integradas. Expandir na ordem dos links e na ordem de cada playlist, sem deduplicar. Acrescentar ao final da coleção; fontes prontas podem participar da execução ativa. Limites e cancelamento explícitos.
5. **Print 7 — MP3 arrastado:** receber arquivo(s) na área da coleção e acrescentar ao final. Criar cópias na pasta da playlist com numeração a partir da última ocorrência, sem mover/alterar o original ou renumerar arquivos já concluídos. Extrair título/artista/capa quando disponíveis; reproduzir a cópia pela biblioteca. Oferecer seleção de arquivos pela mesma operação, inclusive como alternativa mobile.
6. **Validação e entrega:** contratos de ordem/repetição, cancelamento/erro, limite, fontes manuais, adição na execução, cópia sem sobrescrita e original preservado; inspeção visual desktop/mobile, análise/testes/build Windows, backup e atualização do instalado. Só então incrementar/entregar a versão, sem release.

## Direção visual e estrutura

Manter Manrope e a paleta oficial: fundo #FAFAFC, superfícies #F3F4F6, texto #1E293B, framboesa #C9345B, hover #A01F45 e navegação #23273F. Listas alinhadas à esquerda; ícones nas ações existentes. Não acrescentar cartões, sombras, balões ou instruções permanentes. O alvo de MP3 só se destaca durante arraste; erros são concretos e contextuais.

Separar leitura/expansão de links, montagem/persistência de coleção e importação/publicação de mídia local. Widgets só encaminham a intenção e mostram estado. Reutilizar os importadores Dart e os controles da fila; não duplicar uma coleção externa apenas para acrescentá-la em outra. Confirmar fonte, áudio local e download são operações distintas.

## Situação

Etapas 1 a 5 implementadas. Etapa 6: 209 testes passaram, análise sem problemas, build/instalador 0.1.46 e atualização do aplicativo instalado concluídos, com backup e hashes conferidos. Capturas de layouts desktop/mobile e ensaio de cópia com decoder nativo estão registrados em `VERSAO_LOCAL_0_1_46.md`. Falta somente reabrir/conferir a janela instalada e comparar o banco após a migração inicial; sessão Windows bloqueada e desbloqueio solicitado ao usuário. Sem release/tag/push.
