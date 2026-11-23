# 0.1.94 — Espaçamento das páginas e alinhamento das abas

O espaço entre a assinatura do aplicativo e os três atalhos do Início no Windows passou de 4 para 24 px. Os tamanhos dos atalhos e a escala compacta das demais telas foram preservados.

As abas Coleções, Capturar áudio e Downloads agora ficam centralizadas verticalmente com a seta de voltar. O agrupamento da seta com a primeira aba tinha altura maior e fazia as outras abas subirem; o alinhamento compartilhado foi corrigido, mantendo a quebra responsiva quando necessária.

As páginas desktop ganharam margem superior de 24 px, antes de 12 px. O intervalo entre o título da seção e as abas passou de 4 para 12 px, deslocando as abas e o conteúdo 20 px para baixo. No Início, permanece o intervalo próprio de 24 px entre a marca e os atalhos. Os controles continuam com 40 px e a densidade das listas foi preservada. O limite de área útil no teste de Downloads foi ajustado para contemplar os 20 px reservados acima, conforme o novo pedido.

Consolidação 0.1.94+95 para Windows e APKs Android, a pedido do usuário. Sem testes no emulador; o foco de desenvolvimento continua no Windows.

O encerramento da fila autorizou a rodada consolidada de publicação. A regressão identificou transbordamentos em textos e barras de comandos de telas estreitas; os casos foram reproduzidos e corrigidos. A barra de faixas mede o texto do botão de conferência e reserva largura útil para a busca antes de decidir a distribuição. “Outras opções” e o contador de áudios respeitam a largura disponível. O executor limita a concorrência de testes para reduzir a disputa entre verificações com SQLite.

Regressão final: 280 testes Dart aprovados e 3 ignorados; 26 testes do motor offline aprovados e 1 ignorado. Os APKs usam a mesma assinatura de teste da 0.1.88. A publicação consolida as entregas locais 0.1.89–0.1.94; os artefatos definitivos são recompilados a partir desse conjunto.

Em 23/11/2026, o Windows 0.1.94+95 foi instalado e iniciado, com backup privado anterior e verificação de integridade e preservação dos IDs da biblioteca. Os três pacotes definitivos e o SHA256SUMS.txt foram copiados à pasta compartilhada e conferidos por hash. A sessão Windows estava bloqueada na tentativa de conferência da janela instalada; a validação automatizada foi concluída e essa conferência visual ficou pendente. Nenhum emulador foi iniciado para esta publicação.
