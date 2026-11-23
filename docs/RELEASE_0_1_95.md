# Definitive Downloader 0.1.95

Limpeza visual do Início e dos formulários, com resposta mais discreta dos controles.

## Interface

- Atalhos do Início com rótulos diretos, sem descrições, pictogramas ou setas redundantes. Os destinos continuam os mesmos.
- Importação e captura de áudio mantêm os rótulos dos campos, sem repetir as instruções no placeholder.
- Hover e foco mantêm a geometria dos botões e usam destaque de cor. Pressionamentos por ponteiro têm recuo de 3% em 160 ms; teclado, movimento reduzido e controles desabilitados conservam a geometria.
- Densidade das tabelas, cores das playlists e destaque azul do comando de download preservados.

## Pacotes e verificação

Instalador Windows x64 e APKs Android ARM64/x86_64, com assinatura de teste. As somas dos três pacotes estão em `SHA256SUMS.txt`.

Windows já atualizado localmente para 0.1.95+96. Análise estática sem problemas, núcleo essencial e testes focados aprovados; Início conferido por renderização Flutter em 1366×768 e 1024×600.

Cobertura da regressão offline concluída: 281 testes Dart aprovados e 3 ignorados; 26 testes do motor Python aprovados e 1 ignorado. Os casos afetados pela nova regra de hover e dois timeouts da rodada concorrente foram revalidados em uma execução serial de 11 testes. Não houve alteração de limites de espera ou remoção de verificações funcionais.

Android compilado sem iniciar emulador ou executar testes nele, conforme solicitado. A compilação e as verificações dos pacotes não substituem a validação do fluxo em celular.
