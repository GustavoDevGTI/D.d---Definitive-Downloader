"""Bounded transport and sanitized failures for the isolated music engine."""
import json
import re
from urllib.parse import urlparse
import requests


class MusicError(Exception):
    pass


def emit(event, **values):
    print(json.dumps({"event": event, **values}, ensure_ascii=True), flush=True)


def allowed_url(url, domains):
    p = urlparse(url)
    host = (p.hostname or '').lower()
    if p.scheme != 'https' or p.username or p.password or p.port not in (None, 443):
        raise MusicError('Endereço de mídia inválido.')
    if not any(host == d or host.endswith('.' + d) for d in domains):
        raise MusicError('A fonte retornou um domínio não permitido.')
    return url


def bounded_response(response, maximum=1_000_000):
    if response.status_code != 200:
        raise MusicError(f'A fonte respondeu HTTP {response.status_code}.')
    data = bytearray()
    for block in response.iter_content(65536):
        data.extend(block)
        if len(data) > maximum:
            raise MusicError('Resposta da fonte excedeu o limite.')
    return bytes(data)


def json_response(response):
    try:
        result = json.loads(bounded_response(response))
    except (ValueError, UnicodeError):
        raise MusicError('A fonte retornou dados inválidos.') from None
    if not isinstance(result, dict):
        raise MusicError('Resposta de catálogo inválida.')
    return result


def public_bytes(url, maximum=5_000_000):
    # This transport never carries an account cookie or authorization header.
    domains = ['dzcdn.net', 'ytimg.com', 'googleusercontent.com', 'ggpht.com']
    with requests.Session() as session:
        for _ in range(4):
            allowed_url(url, domains)
            with session.get(url, timeout=(10, 20), stream=True, allow_redirects=False) as response:
                if response.is_redirect:
                    from urllib.parse import urljoin
                    url = urljoin(url, response.headers.get('Location', ''))
                    continue
                return bounded_response(response, maximum)
    raise MusicError('Muitos redirecionamentos na imagem.')


def clean_text(value):
    return str(value or '')[:500].replace('\r', ' ').replace('\n', ' ')


def check_duration(actual, expected):
    if not actual or actual < 1000 or not expected or abs(actual - expected) > 2000:
        raise MusicError(f'Duração diferente da faixa escolhida '
                         f'({actual or 0} ms recebidos; {expected or 0} ms esperados). '
                         'Revise a correspondência; o arquivo foi recusado.')


def identifier(value, pattern):
    if not re.fullmatch(pattern, str(value)):
        raise MusicError('Identificador de faixa inválido.')
    return str(value)
