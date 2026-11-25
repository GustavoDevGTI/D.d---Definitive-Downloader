# 0.1.96 — Biblioteca, atualização Windows e login Deezer

Correção desktop Windows 0.1.96+97. O relato veio de outro computador com Windows 11 e uma instalação anterior aproximadamente 0.1.65. Não foi recebida uma cópia do banco desse computador; os cenários históricos abaixo são testes isolados, não reprodução dos dados daquela pessoa.

## Biblioteca

Um teste pelo importador real reproduziu a mensagem da imagem: uma falha que já desfaz a transação era substituída por `cannot rollback - no transaction is active`. A limpeza agora verifica `autocommit` e preserva a exceção original, inclusive se a própria limpeza falhar. A proteção foi aplicada aos caminhos de importação, edição, migração, organização, fila e recuperação que faziam rollback incondicional.

O teste provoca um rollback real no SQLite durante a inserção, exige a mensagem original, verifica que a importação incompleta é removida e faz outra importação com sucesso. A causa inicial no outro computador permanece desconhecida; esta correção impede que ela seja ocultada pelo erro secundário.

Removida a imposição de `winsqlite3.dll`. O carregador do pacote SQLite volta a priorizar a biblioteca distribuída com o aplicativo, reduzindo a dependência da versão do SQLite do Windows. Não muda o formato nem a versão do schema.

Teste de migração histórica ampliado: após reconstruir e migrar um schema antigo, renomear playlist, editar uma faixa ainda não iniciada e selecionar para uso preservam ID e posição; `quick_check` é verificado. Os testes existentes conservam arquivos, histórico, repetições e proteção das faixas já iniciadas/concluídas. Não se desbloqueiam coleções indiscriminadamente nem se apagam dados antigos.

Referências: [transações SQLite](https://www.sqlite.org/lang_transaction.html), [reutilização do diretório no instalador](https://jrsoftware.org/ishelp/topic_setup_usepreviousappdir.htm).

## Atualização e desinstalação

AppId continua igual ao da primeira versão publicada. O instalador explicita a reutilização do diretório e tarefas anteriores, oculta a escolha de outro diretório durante uma atualização registrada e mantém um único cadastro de aplicativo. Não executa o desinstalador antigo antes de atualizar a biblioteca.

Desinstalador e cadastro no Windows explicitamente habilitados; acrescentado **Desinstalar Definitive Downloader** no menu Iniciar. Biblioteca e mídias ficam fora da lista de arquivos do instalador e não há limpeza de dados pessoais na desinstalação.

`tools/test_windows_installer.ps1` usa identidade, pasta e atalhos exclusivos de fixture. Confirmou atualização 0.1.95 → 0.1.96 no mesmo destino, substituição do conteúdo, cadastro único, preservação da biblioteca externa e presença de desinstalador/atalho. A revisão automática bloqueou executar o desinstalador isolado, sem motivo detalhado. A execução foi pulada com `-SkipUninstall`; não é declarada aprovada. O registro de fixture foi conservado, com evidência privada, sem modificar a instalação real durante esse teste.

## Deezer

O formulário oficial recebe uma restrição de interface somente em origem HTTPS da Deezer: botões sociais ficam desabilitados, fora da sequência de Tab e sem ativação por ponteiro/teclado. Observação de alterações do DOM cobre a montagem tardia dos controles. A navegação externa continua bloqueada como defesa adicional. E-mail/senha e recuperação de senha permanecem disponíveis.

O script não lê senhas, valores dos campos ou cookies. A captura e validação da sessão continuam no adaptador nativo. O diagnóstico Windows existente ganhou fixture para Google, Facebook, Apple inserido dinamicamente e envio normal por e-mail, sem conta ou acesso a dados pessoais.

## Validação

Análise sem problemas; 102 testes essenciais e focados aprovados, 1 ignorado. O ajuste final de proteção do callback assíncrono do formulário também passou na análise focada. O teste do rollback foi observado falhando com a mensagem idêntica à imagem antes da correção e passou no conjunto final.

Compilação Windows Release e instalador concluídos. Diagnóstico nativo saiu com código 0 e `DD_WEB_LOGIN_OK`: cookie sintético e restrição dos controles sociais verificados, incluindo botão inserido posteriormente, clique em elemento filho e envio normal de e-mail. Não houve uso de conta real ou validação de um novo login real na página remota da Deezer.

Instalação local atualizada de 0.1.95 para 0.1.96 no mesmo diretório, com um único cadastro Windows e atalho **Desinstalar Definitive Downloader** confirmado. Processo instalado carregou `sqlite3.dll` da própria pasta do aplicativo. Antes da atualização foi feita cópia privada consistente; após ela, integridade, IDs de coleções/faixas/histórico, posições e caminhos dos concluídos e versão do schema permaneceram preservados.

Instalador copiado à pasta compartilhada, com hash conferido: `c3ae749b88183d1cec7cd227c59bf4e5cb240cac862711a504be83df11cb6da6`. A correção precisa ser retestada com o banco específico do outro PC para identificar eventual erro primário ainda existente. Sem emulador, APK ou publicação nesta etapa.
