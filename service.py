#!/usr/bin/env python3
"""
Windows Service wrapper para o servidor de bypass.
Instalação:  python service.py install
Remoção:     python service.py remove
Start/Stop:  python service.py start / stop
(ou via services.msc)
"""
import sys
import os
import time
import threading

# Tenta importar pywin32; se não tiver, avisa e usa fallback
try:
    import win32serviceutil
    import win32service
    import win32event
    import servicemanager
    HAS_WIN32 = True
except ImportError:
    HAS_WIN32 = False

SERVICE_NAME    = 'CatalogoExpressoBypass'
SERVICE_DISPLAY = 'Catálogo Direct Evolution – Bypass Server'
SERVICE_DESC    = 'Servidor local que intercepta validação de chave do CatalogoExpresso'

# ── Servidor embutido (mesma lógica de server.py) ──────────────────────────────
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.request, urllib.error, datetime, socket

REAL_SERVER_IP = '189.113.2.50'
LISTEN_PORT    = 8080
LISTEN_HOST    = '127.0.0.1'


def build_log_path():
    base = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base, 'service.log')


LOG_PATH = build_log_path()


def log(msg):
    ts = datetime.datetime.now().strftime('%H:%M:%S')
    line = f'[{ts}] {msg}'
    try:
        with open(LOG_PATH, 'a', encoding='utf-8') as f:
            f.write(line + '\n')
    except Exception:
        pass


def proxy_to_real(path, method, body, orig_headers):
    url = f'http://{REAL_SERVER_IP}{path}'
    req = urllib.request.Request(url, data=body if body else None, method=method)
    for key in ('User-Agent', 'Content-Type'):
        val = orig_headers.get(key)
        if val:
            req.add_header(key, val)
    req.add_header('Host', 'www.ideia2001.com.br')
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.read()
    except Exception as e:
        log(f'PROXY ERROR {url}: {e}')
        return b''


class BypassHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args): pass

    def _body(self):
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
        body = self._body()
        if 'CadastraCliente' in self.path:
            log(f'BYPASS CadastraCliente -> "10"')
            self._send(b'10')
        elif 'Vers2' in self.path:
            now = datetime.datetime.now().strftime('%d/%m/%Y %H:%M:%S')
            self._send(f'120|139|2||0||{now}|1;0;;0;0|||||||3908280||0|1|||1|0|0|1|'.encode())
        else:
            self._send(proxy_to_real(self.path, 'POST', body, self.headers))

    def do_GET(self):
        self._send(proxy_to_real(self.path, 'GET', None, self.headers))


_server_instance = None
_server_thread   = None


def start_server():
    global _server_instance, _server_thread
    _server_instance = HTTPServer((LISTEN_HOST, LISTEN_PORT), BypassHandler)
    log(f'Server started on {LISTEN_HOST}:{LISTEN_PORT}')
    _server_thread = threading.Thread(target=_server_instance.serve_forever, daemon=True)
    _server_thread.start()


def stop_server():
    global _server_instance
    if _server_instance:
        _server_instance.shutdown()
        _server_instance = None
    log('Server stopped')


# ── Windows Service class ─────────────────────────────────────────────────────
if HAS_WIN32:
    class BypassService(win32serviceutil.ServiceFramework):
        _svc_name_        = SERVICE_NAME
        _svc_display_name_= SERVICE_DISPLAY
        _svc_description_ = SERVICE_DESC

        def __init__(self, args):
            win32serviceutil.ServiceFramework.__init__(self, args)
            self._stop_event = win32event.CreateEvent(None, 0, 0, None)

        def SvcStop(self):
            self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
            win32event.SetEvent(self._stop_event)
            stop_server()

        def SvcDoRun(self):
            servicemanager.LogMsg(
                servicemanager.EVENTLOG_INFORMATION_TYPE,
                servicemanager.PYS_SERVICE_STARTED,
                (self._svc_name_, ''))
            start_server()
            win32event.WaitForSingleObject(self._stop_event, win32event.INFINITE)


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == '__main__':
    if not HAS_WIN32:
        print('[!] pywin32 não instalado. Instalando...')
        import subprocess
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'pywin32'])
        print('[+] Reinicie o script.')
        sys.exit(0)

    if len(sys.argv) == 1:
        # Rodando como serviço pelo SCM
        servicemanager.Initialize()
        servicemanager.PrepareToHostSingle(BypassService)
        servicemanager.StartServiceCtrlDispatcher()
    else:
        win32serviceutil.HandleCommandLine(BypassService)
