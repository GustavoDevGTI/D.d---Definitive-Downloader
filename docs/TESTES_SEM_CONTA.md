# Viabilidade sem conta — 27/10/2026

Nenhuma conta, senha, cookie ou token do usuário foi utilizado. O resultado desta etapa **não comprova download de áudio completo do Spotify**. A autenticação ficou para uma etapa posterior por instrução do usuário.

## Repositórios verificados

| Projeto | Revisão | Verificação | Resultado e alcance |
| --- | --- | --- | --- |
| [Zotify](https://github.com/zotify-dev/zotify) | `08d844fe3e644ae6cd9bea34a3b4982e61129f33` | Instalação isolada, CLI e execução sem credenciais, com entrada encerrada | Solicita usuário e termina com EOF/exit 1. Sem sessão não avançou até obter áudio. Isso não demonstra impossibilidade com autenticação. |
| [librespot](https://github.com/librespot-org/librespot) | `99b6088bf3ea028f90192676ac1a337fa4b2ed12` | Inspeção do código e dos mecanismos de sessão | Não compilado nem executado: toolchain Rust não instalada. Não foi validado como pipeline de playlist para MP3. |
| [spotDL](https://github.com/spotDL/spotify-downloader) | `58ced9af69dce17d33ff280bafbcc917a9dba0aa` | Instalação isolada, CLI, suíte offline, leitura pública e rotinas de tags | 164 testes passaram; 1 skipped, 58 testes live excluídos, 4 xfailed. A leitura pública reconheceu 50 faixas de uma playlist, mas não terminou dentro de 35 segundos. Nenhum download de música completa foi comprovado. |

Zotify e spotDL foram instalados em ambientes virtuais separados, fora dos fontes do app. Esses motores não foram incorporados ao executável Flutter. spotDL busca áudio em outra fonte: uma entrada Spotify não significa áudio extraído do Spotify.

## Reprodução e evidências

Na pasta do spotDL, usando o Python de seu ambiente virtual:

```powershell
python -m pytest -q -m 'not live' --record-mode=none --block-network --allowed-hosts=127.0.0.1,localhost --tb=short
```

A primeira execução bloqueou também sockets de loopback usados pelo asyncio no Windows. A segunda permitiu somente localhost; as falhas desapareceram sem alterar os testes. O resultado acima corresponde à segunda execução. O aviso remanescente é de depreciação do evento de encerramento no FastAPI.

O comando público foi `spotdl save https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M --save-file <arquivo-temporario> --no-cache --max-retries 0 --headless --ffmpeg <ffmpeg-local>`, encerrado pelo harness em 35 segundos. Esse ensaio testa descoberta de metadados, não download de áudio. Consulte o log para o alcance exato, sem interpretar timeout como sucesso completo.

As rotinas de tags de Zotify e spotDL foram verificadas separadamente com MP3 sintético de aproximadamente quatro segundos e imagem servidos em localhost. Ambos geraram título e capa APIC verificáveis com Mutagen. É um teste de metadados, não de obtenção de música do catálogo.

Logs preservados em [evidencias/](evidencias/): `zotify-no-account.log`, `zotify-mp3-cover.log`, `spotdl-mp3-cover.log`, `spotdl-offline-tests-loopback.log`, `spotdl-public-metadata.log` e `catalog-probe.log`.

## Integrações da primeira versão Flutter

- **Spotify público:** o parser tem testes de conteúdo sintético e identifica resultados como parciais. Na requisição real deste ambiente, o cliente Dart falhou com `CERTIFICATE_VERIFY_FAILED` por emissor local não reconhecido. A validação TLS foi mantida. A falha deste cliente não invalida o resultado diferente do spotDL, que usa outra biblioteca e armazenamento de certificados.
- **Deezer público:** a consulta real por `Kevin MacLeod Carefree` retornou um candidato com URL de prévia. Não foi solicitado áudio completo. A interface identifica explicitamente prévias.
- **YouTube Music:** nesta entrega há pesquisa externa pelo navegador. Ainda não há adaptador para obtenção automática de arquivos completos.
- **MP3 direto:** o app aceita uma fonte MP3 vinculada manualmente, com validação de formato, limites de transferência e capa opcional. Os testes automatizados usaram servidor local com áudio sintético.

## Decisão para a continuidade

Manter o produto independente dos extratores. A primeira base desktop permite importar, conferir fontes e salvar arquivos ordenados; a próxima integração precisa comprovar a obtenção de áudio completo antes de ser apresentada como concluída. Para Spotify, testar autenticação local apenas quando o usuário retomar essa etapa. Para fontes alternativas, validar procedência e correspondência da gravação; título semelhante ou preview disponível não bastam.
