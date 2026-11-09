import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

TOKEN = 'eyJ.fixture.renewed'
class Handler(BaseHTTPRequestHandler):
    expired = False

    def log_message(self, *args):
        pass

    def reply(self, status, data):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlparse(self.path).path
        if path == '/authorize':
            self.send_response(302)
            self.send_header('Location', 'beszel-companion://redirect?code=fixture-code')
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        if path.startswith('/unavailable/'):
            return self.reply(503, {'message': 'Fixture server unavailable'})
        if self.headers.get('X-Reauth-Test') != 'preserved':
            return self.reply(403, {'message': 'Missing fixture header'})
        if path.endswith('/auth-methods'):
            return self.reply(200, {'password': {'enabled': True}, 'oauth2': {'enabled': True, 'providers': [
                {'name': 'oidc', 'displayName': 'Test SSO', 'authUrl': 'http://127.0.0.1:47898/authorize?redirect_uri=', 'codeVerifier': 'test-verifier'}
            ]}})
        if self.expired or self.headers.get('Authorization') != 'Bearer ' + TOKEN:
            return self.reply(401, {'message': 'Fixture session expired'})
        items = [{'id': 'testserver', 'name': 'OIDC Server', 'status': 'up'}] if '/systems/' in path else []
        return self.reply(200, {'page': 1, 'perPage': 100, 'totalPages': 1, 'totalItems': len(items), 'items': items})

    def do_POST(self):
        path = urlparse(self.path).path
        body = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))) or '{}')
        if path == '/test/expire':
            Handler.expired = True
            return self.reply(200, {})
        if path.startswith('/unavailable/'):
            return self.reply(503, {'message': 'Fixture server unavailable'})
        if self.headers.get('X-Reauth-Test') != 'preserved':
            return self.reply(403, {'message': 'Missing fixture header'})
        if path.endswith('/auth-refresh') and (self.expired or self.headers.get('Authorization') != 'Bearer ' + TOKEN):
            return self.reply(401, {'message': 'Fixture session expired'})
        if path.endswith('/auth-with-oauth2') and (body.get('code') != 'fixture-code' or body.get('codeVerifier') != 'test-verifier'):
            return self.reply(400, {'message': 'Invalid fixture code exchange'})
        if path.endswith('/auth-with-password') and body.get('password') != 'fixture-password':
            return self.reply(400, {'message': 'Invalid fixture password'})
        Handler.expired = False
        return self.reply(200, {'token': TOKEN, 'record': {'email': 'test@example.invalid'}})

print('OIDC test hub listening on 127.0.0.1:47898', flush=True)
ThreadingHTTPServer(('127.0.0.1', 47898), Handler).serve_forever()
