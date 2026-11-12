"""HTTP server with Range support for the streaming labs (chapters 12 and 13). Serves one directory and logs every request.
Usage: range-server.py DIR PORT LOGFILE [SERVER_CERT SERVER_KEY CLIENT_CA]
With the last three arguments the server speaks TLS and requires a client certificate that chains to CLIENT_CA (mutual TLS).
Each request is logged with the common name of the client certificate, and each refused handshake is logged as REFUSED."""
import os, re, ssl, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
ROOT, PORT, LOG = sys.argv[1], int(sys.argv[2]), sys.argv[3]
TLS = sys.argv[4:7] if len(sys.argv) >= 7 else None
def log(line):
    with open(LOG, "a") as f: f.write(line + "\n")
class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *a): pass
    def setup(self):
        if TLS:
            try: self.request.do_handshake()
            except (ssl.SSLError, OSError) as e:
                log(f"REFUSED {self.client_address[0]} {getattr(e, 'reason', None) or e}")
                self.request.close(); raise ConnectionAbortedError("handshake refused")
        super().setup()
    def handle(self):
        try: super().handle()
        except (ConnectionAbortedError, BrokenPipeError, ConnectionResetError): pass
    def _cn(self):
        if not TLS: return "-"
        cert = self.request.getpeercert() or {}
        return next((v for rdn in cert.get("subject", ()) for k, v in rdn if k == "commonName"), "-")
    def _send(self, body_too):
        path = os.path.join(ROOT, os.path.basename(self.path))
        if not os.path.isfile(path):
            self.send_response(404); self.send_header("Content-Length", "0"); self.end_headers(); return
        size = os.path.getsize(path); start, end, code = 0, size - 1, 200
        m = re.match(r"bytes=(\d*)-(\d*)", self.headers.get("Range", ""))
        if m and (m.group(1) or m.group(2)):
            if m.group(1): start = int(m.group(1)); end = int(m.group(2)) if m.group(2) else size - 1
            else: start = max(0, size - int(m.group(2)))
            end = min(end, size - 1); code = 206
        n = end - start + 1
        self.send_response(code); self.send_header("Accept-Ranges", "bytes"); self.send_header("Content-Length", str(n))
        if code == 206: self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.end_headers()
        log(f"{self.command} {os.path.basename(self.path)} {start} {n} {size} {self._cn()}")
        if body_too:
            with open(path, "rb") as f:
                f.seek(start); left = n
                while left:
                    chunk = f.read(min(65536, left)); self.wfile.write(chunk); left -= len(chunk)
    def do_GET(self): self._send(True)
    def do_HEAD(self): self._send(False)
class Server(ThreadingHTTPServer):
    def get_request(self):
        sock, addr = self.socket.accept()
        if TLS: sock = CTX.wrap_socket(sock, server_side=True, do_handshake_on_connect=False)
        return sock, addr
    def handle_error(self, request, client_address): pass
if TLS:
    CTX = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    CTX.load_cert_chain(TLS[0], TLS[1]); CTX.load_verify_locations(TLS[2]); CTX.verify_mode = ssl.CERT_REQUIRED
Server(("0.0.0.0", PORT), H).serve_forever()
