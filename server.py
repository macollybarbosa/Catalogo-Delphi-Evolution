#!/usr/bin/env python3
"""
Catálogo Direct Evolution - Bypass Server
Intercepts CadastraCliente.asp (key validation) and proxies everything
else to the real server IP, so catalog data is always fresh.

Listens on 127.0.0.1:8080
Requires portproxy: 127.0.0.1:80 -> 8080 (setup.ps1 configures this)
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.request
import urllib.error
import datetime
import sys
import os

REAL_SERVER_IP = '189.113.2.50'
LISTEN_PORT    = 80
LISTEN_HOST    = '127.0.0.1'

LOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'server.log')


def log(msg):
    ts = datetime.datetime.now().strftime('%H:%M:%S')
    line = f'[{ts}] {msg}'
    print(line, flush=True)
    try:
        with open(LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(line + '\n')
    except Exception:
        pass


def proxy_to_real(path, method, body, orig_headers):
    url = f'http://{REAL_SERVER_IP}{path}'
    req = urllib.request.Request(url, data=body if body else None, method=method)
    for key in ('User-Agent', 'Content-Type', 'Accept'):
        val = orig_headers.get(key)
        if val:
            req.add_header(key, val)
    req.add_header('Host', 'www.ideia2001.com.br')
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = resp.read()
            log(f'  PROXY -> {url}  resp={len(data)}B [{data[:40]}]')
            return data
    except urllib.error.URLError as e:
        log(f'  PROXY ERROR -> {url}: {e}')
        return b''


class BypassHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # suppress default access log

    def _read_body(self):
        n = int(self.headers.get('Content-Length', 0))
        return self.rfile.read(n) if n > 0 else b''

    def _send(self, data):
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Connection', 'close')
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        body = self._read_body()
        path = self.path

        log(f'POST {path}  body={len(body)}B')

        if 'CadastraCliente' in path:
            # KEY BYPASS: always return flag=1, clientCode=0
            response = b'10'
            log(f'  BYPASS CadastraCliente -> "10"')

        elif 'Vers2' in path:
            # Version check: return current timestamp so app thinks it's up to date
            now = datetime.datetime.now().strftime('%d/%m/%Y %H:%M:%S')
            response = f'120|139|2||0||{now}|1;0;;0;0|||||||3908280||0|1|||1|0|0|1|'.encode()
            log(f'  BYPASS Vers2 -> current datetime')

        else:
            # Proxy everything else (RetDadosLocalizacao, images, etc.) to real server
            response = proxy_to_real(path, 'POST', body, self.headers)

        self._send(response)

    def do_GET(self):
        log(f'GET {self.path}')
        response = proxy_to_real(self.path, 'GET', None, self.headers)
        self._send(response)


if __name__ == '__main__':
    try:
        server = HTTPServer((LISTEN_HOST, LISTEN_PORT), BypassHandler)
        log(f'CatalogoExpresso bypass server listening on {LISTEN_HOST}:{LISTEN_PORT}')
        log(f'Real server proxied at http://{REAL_SERVER_IP}/')
        log('Press Ctrl+C to stop')
        server.serve_forever()
    except OSError as e:
        log(f'ERROR: {e}')
        if 'Address already in use' in str(e) or '10048' in str(e):
            log('Port 8080 is already in use. Kill the existing process first.')
        sys.exit(1)
    except KeyboardInterrupt:
        log('Stopped.')
