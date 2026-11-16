# 0.1.68 — guia de visibilidade da playlist Spotify

Em **Músicas → Coleções → Importar por link**, quando o serviço informa que a playlist Spotify não está acessível publicamente, o D.d abre um guia com a sequência **⋯ → Tornar pública**. A animação dura cerca de três segundos. O botão **Abrir Spotify Web** antecipa a abertura, e a preferência do sistema por menos movimento pula a animação.

O mesmo modal abre a página oficial de login do Spotify com retorno para a playlist. Se precisar, **Abrir playlist** navega diretamente para ela. A pessoa altera a visibilidade no Spotify e clica em **Tentar importar novamente** para usar o link original. Se o link continuar inacessível, o modal mantém a sessão Web e mostra a orientação. **Abrir no navegador** oferece outro caminho se o login ou a página falhar na janela integrada.

A leitura continua pelo serviço público da 0.1.67. O login serve para a pessoa ajustar a playlist no Spotify. O D.d não consulta cookies, senhas ou tokens do Spotify nesse fluxo.
