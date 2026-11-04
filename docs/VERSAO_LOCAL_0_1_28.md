# Definitive Downloader 0.1.28 — versão local

Identificação `0.1.28+29`, em 04/11/2026. Sem release, tag ou publicação remota.

A barra da playlist passa a conter três ações: Baixar selecionadas, Adicionar links e Rever correspondências. O terceiro botão substitui o atalho circular de Downloads, com ícone de lista/conferência (`fact_check_outlined`) e cor vinho. Executa a mesma reconferência antes disponível no menu: busca automática da coleção, mantendo fontes manuais e faixas concluídas. A disponibilidade continua dependendo do motor e do estado ocupado; exemplos locais não acionam provedores.

Removidos os três pontos e seu menu, sem espaço reservado. Downloads permanece acessível pela aba da categoria e após iniciar o download das selecionadas. Os controles específicos da faixa permanecem dentro de Conferência, abaixo da pesquisa, conforme a 0.1.27.

## Validação e instalação

Código formatado, análise estática sem problemas e build Windows release concluído. Os seis testes de layout existentes passaram novamente a 1920×1080, 1360×820, 900×820, 900×600, 390×820 e 320×820 (texto 1,3× na menor largura). Capturas desktop/mobile inspecionadas. Apenas a ligação e a apresentação da ação foram alteradas; a reconferência mantém as regras já testadas. Sem novo ensaio real de provedor; sem execução nativa Android/iOS.

Instalador local executado com saída 0; app reaberto da instalação. ProductVersion do executável 0.1.28+29 e cadastro de Aplicativos do Windows 0.1.28 conferidos. Backup local de SQLite, executável e app.so anterior à atualização. Depois da instalação e após reabrir: schema 10, quick_check=ok, zero ativos e banco integralmente preservado por hash (duas coleções, 242 ocorrências, dez históricos, dez preferências, 2183 candidatos, dez tentativas e zero grupos).

118 fontes/testes/assets iguais ao staging compilado. Executável, app.so, flutter_windows.dll, ICO e worker iguais por SHA-256 entre pacote e instalação; worker preservado em 266B509F026A92827FA48E8335BF59865BB6B1B06552E56DB48276145D01D271. Instalador, backup e evidências permanecem somente no diretório local privado. Sem tag, push ou release.
