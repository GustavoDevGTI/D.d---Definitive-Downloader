# 0.1.93 — Escala consistente no desktop

O padrão dos controles de Downloads foi aplicado ao restante da interface Windows, com definições centrais em `AppDensity` e no tema. Ver ESCALA_DESKTOP.md.

- Botões de 40 px e ícones de 20 px em Coleções, Conferência, captura de áudio, Arquivos, Configurações e conexões.
- Campos, tipografia de formulários, cantos e diálogos seguem a mesma escala.
- Margens de 14 px e cabeçalhos de seção menores ampliam a área útil em todas as categorias.
- Coleções usa capas de 32 px, linhas de 52 px e cabeçalho de 32 px. Busca e comandos compartilham a linha quando a largura permite, incluindo o painel desktop com Conferência ao lado.
- Configurações usa linhas com divisores; navegação por pastas, atalhos do Início e controles de escuta foram ajustados.
- Player com capa de 40 px, controles de 40 px e barra inferior mais baixa. O botão central continua circular.
- Cores das playlists, identidade da marca e destaque azul de download preservados. Importação, conferência, seleção e download mantêm suas ações.

Validação local: análise estática, essenciais e testes focados de interface, seleção, arraste, rolagem contínua, diálogos e player. A rodada de páginas desktop em 1360×820 passou, com capturas inspecionadas de Coleções, Conferência e Configurações. O teste de área de Downloads passou em 1366×768 e 1024×600. Os ajustes finais de tipografia e cabeçalho foram conferidos novamente junto da seleção e do arraste. As falhas intermediárias do limite de altura foram corrigidas reduzindo o espaço do cabeçalho, preservando a área da tabela.

Versão local 0.1.93+94. Windows; Android pausado, sem emulador ou APK. Sem release no GitHub.

Conclusão em 23/11/2026: instalador aplicado à instalação Windows e aplicativo aberto. Criado backup privado atualizado do SQLite antes da instalação; integridade e preservação dos IDs de coleções, faixas e histórico verificadas depois. Pacote e SHA-256 copiados à pasta compartilhada, com hash da cópia conferido. A janela real foi inspecionada no Início, na lista de playlists e dentro da Fifa definitivo. Controles de 40 px alinhados à busca, cores da playlist e lista compacta observados; aplicativo deixado aberto nessa playlist.
