#!/usr/bin/env python3
"""
Admin API server for managing WebDAV users.
Serves the admin HTML page and provides REST endpoints for user management.
Runs on port 8080, proxied by nginx at /admin.
"""

import http.server
import json
import os
import shutil
import subprocess
import urllib.parse
from pathlib import Path

HTPASSWD_DIR = Path("/etc/nginx/webdav_credentials")
WEBDAV_DIR = Path("/var/www/webdav")
USERS_FILE = WEBDAV_DIR / ".users"
NGINX_CONF = Path("/etc/nginx/sites-enabled/webdav")
ADMIN_HTML = Path("/opt/admin/admin.html")
PORT = 8080

# Nginx config template — kept here so we can regenerate after add/remove.
# The entrypoint script also uses this same structure on initial startup.
NGINX_TEMPLATE = """server {
  listen 80 default_server;
  server_name _;

  root /var/www/webdav;
  autoindex on;

  client_max_body_size __CLIENT_MAX_BODY_SIZE__;
  charset UTF-8;

  # Public pages — no authentication, open to everyone.
  # Exact-match locations so a user like "sign" cannot shadow these paths.
  location = /signup.html {
    access_log             /dev/stdout;
    error_log              /dev/stdout;
  }

  location = /signup {
    # Relative Location header, so the browser keeps the port it connected on
    # (absolute redirects are built from $host, which has no port).
    absolute_redirect  off;
    return 302 /signup.html;
  }

  location /public {
    dav_methods            PUT DELETE MKCOL COPY MOVE;
    dav_ext_methods        PROPFIND OPTIONS;
    dav_access             user:rw group:rw;

    create_full_put_path   on;

    error_log              /dev/stdout;
    access_log             /dev/stdout;

    # Handle CORS preflight before auth runs
    if ($request_method = 'OPTIONS') {
      add_header 'Access-Control-Allow-Origin' '*' always;
      add_header 'Access-Control-Allow-Methods' 'GET, PUT, DELETE, MKCOL, COPY, MOVE, OPTIONS, PROPFIND, PROPPATCH' always;
      add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, Depth, Destination, If, Lock-Token, Overwrite, Timeout' always;
      add_header 'Access-Control-Max-Age' 1728000;
      add_header 'Content-Type' 'text/plain; charset=utf-8';
      add_header 'Content-Length' 0;
      return 204;
    }

    # always ensures headers are sent on 401/4xx/5xx too
    add_header 'Access-Control-Allow-Origin'   '*' always;
    add_header 'Access-Control-Allow-Methods'  'GET, PUT, DELETE, MKCOL, COPY, MOVE, OPTIONS, PROPFIND, PROPPATCH' always;
    add_header 'Access-Control-Allow-Headers'  'Authorization, Content-Type, Depth, Destination, If, Lock-Token, Overwrite, Timeout' always;
    add_header 'Access-Control-Expose-Headers' 'Content-Length, Content-Range, Date, ETag, Lock-Token' always;
  }

  location /admin {
    auth_basic             "Admin";
    auth_basic_user_file   /etc/nginx/webdav_credentials_admin;

    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }

__USER_LOCATIONS__
}
"""


def list_users():
    """List all users by reading the htpasswd directory."""
    users = []
    if HTPASSWD_DIR.exists():
        for f in sorted(HTPASSWD_DIR.iterdir()):
            if f.is_file() and f.name != "admin":
                users.append(f.name)
    return users


def generate_user_location_block(username, htpasswd_dir):
    """Generate an nginx location block for a single user."""
    return f"""
  location /{username} {{
    auth_basic             "Restricted";
    auth_basic_user_file   {htpasswd_dir}/{username};

    dav_methods            PUT DELETE MKCOL COPY MOVE;
    dav_ext_methods        PROPFIND OPTIONS;
    dav_access             user:rw group:rw;

    create_full_put_path   on;

    error_log              /dev/stdout;
    access_log             /dev/stdout;

    # Handle CORS preflight before auth runs
    if ($request_method = 'OPTIONS') {{
      add_header 'Access-Control-Allow-Origin' '*' always;
      add_header 'Access-Control-Allow-Methods' 'GET, PUT, DELETE, MKCOL, COPY, MOVE, OPTIONS, PROPFIND, PROPPATCH' always;
      add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, Depth, Destination, If, Lock-Token, Overwrite, Timeout' always;
      add_header 'Access-Control-Max-Age' 1728000;
      add_header 'Content-Type' 'text/plain; charset=utf-8';
      add_header 'Content-Length' 0;
      return 204;
    }}

    # always ensures headers are sent on 401/4xx/5xx too
    add_header 'Access-Control-Allow-Origin'   '*' always;
    add_header 'Access-Control-Allow-Methods'  'GET, PUT, DELETE, MKCOL, COPY, MOVE, OPTIONS, PROPFIND, PROPPATCH' always;
    add_header 'Access-Control-Allow-Headers'  'Authorization, Content-Type, Depth, Destination, If, Lock-Token, Overwrite, Timeout' always;
    add_header 'Access-Control-Expose-Headers' 'Content-Length, Content-Range, Date, ETag, Lock-Token' always;
  }}"""


def get_current_client_max_body_size():
    """Read the current client_max_body_size from the nginx config."""
    import re
    if NGINX_CONF.exists():
        content = NGINX_CONF.read_text()
        match = re.search(r"client_max_body_size\s+(\S+);", content)
        if match:
            return match.group(1)
    return "250M"


def regenerate_nginx_config():
    """Regenerate the nginx config from the template + current user list."""
    users = list_users()
    user_blocks = ""
    for username in users:
        user_blocks += generate_user_location_block(username, str(HTPASSWD_DIR))

    client_max_body_size = get_current_client_max_body_size()
    config = NGINX_TEMPLATE.replace("__CLIENT_MAX_BODY_SIZE__", client_max_body_size)
    config = config.replace("__USER_LOCATIONS__", user_blocks)
    NGINX_CONF.write_text(config)


def reload_nginx():
    """Reload nginx configuration."""
    subprocess.run(["nginx", "-s", "reload"], capture_output=True)


def read_users_file():
    """Read the persistent users file."""
    users = {}
    if USERS_FILE.exists():
        for line in USERS_FILE.read_text().splitlines():
            line = line.strip()
            if ":" in line:
                username, password = line.split(":", 1)
                users[username] = password
    return users


def write_users_file(users):
    """Write the persistent users file."""
    lines = [f"{username}:{password}" for username, password in sorted(users.items())]
    USERS_FILE.write_text("\n".join(lines) + "\n" if lines else "")


def add_user(username, password):
    """Add a new user: htpasswd file, directory, nginx config, persistence."""
    if not username or not password:
        return False, 400, "Username and password are required"
    if not username.isalnum() and not all(c.isalnum() or c in "-_" for c in username):
        return False, 400, "Username must be alphanumeric (hyphens and underscores allowed)"
    if HTPASSWD_DIR.joinpath(username).exists():
        return False, 404, f"User '{username}' already exists"

    # Create htpasswd file
    htpasswd_file = HTPASSWD_DIR / username
    result = subprocess.run(
        ["htpasswd", "-bc", str(htpasswd_file), username, password],
        capture_output=True
    )
    if result.returncode != 0:
        return False, 500, f"Failed to create credentials: {result.stderr.decode()}"

    # Create user directory
    user_dir = WEBDAV_DIR / username
    user_dir.mkdir(exist_ok=True)
    subprocess.run(["chown", "www-data:www-data", str(user_dir)], capture_output=True)

    # Regenerate nginx config and reload
    regenerate_nginx_config()
    reload_nginx()

    # Persist to users file
    users = read_users_file()
    users[username] = password
    write_users_file(users)

    return True, 201, f"User '{username}' created successfully"


def remove_user(username):
    """Remove a user: htpasswd file, directory, nginx config, persistence."""
    htpasswd_file = HTPASSWD_DIR / username
    user_dir = WEBDAV_DIR / username

    if not htpasswd_file.exists():
        return False, f"User '{username}' does not exist"

    # Remove htpasswd file
    htpasswd_file.unlink()

    # Remove user directory
    if user_dir.exists():
        shutil.rmtree(str(user_dir))

    # Regenerate nginx config and reload
    regenerate_nginx_config()
    reload_nginx()

    # Remove from users file
    users = read_users_file()
    users.pop(username, None)
    write_users_file(users)

    return True, f"User '{username}' removed successfully"


class AdminHandler(http.server.BaseHTTPRequestHandler):
    """HTTP handler for the admin API and static files."""

    def log_message(self, format, *args):
        """Suppress default logging."""
        pass

    def send_json(self, data, status=200):
        """Send a JSON response."""
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_html(self, filepath):
        """Send an HTML file."""
        if not filepath.exists():
            self.send_error(404, "File not found")
            return
        content = filepath.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path

        if path == "/admin" or path == "/admin/":
            self.send_html(ADMIN_HTML)
        elif path == "/admin/api/users":
            users = list_users()
            self.send_json({"users": users})
        else:
            self.send_error(404)

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path

        if path == "/admin/api/users":
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            try:
                data = json.loads(body)
            except json.JSONDecodeError:
                self.send_json({"error": "Invalid JSON"}, 400)
                return

            username = data.get("username", "").strip()
            password = data.get("password", "").strip()
            success, status,message = add_user(username, password)
            self.send_json({"success": success, "message": message}, status)
        else:
            self.send_error(404)

    def do_DELETE(self):
        path = urllib.parse.urlparse(self.path).path

        if path.startswith("/admin/api/users/"):
            username = path.split("/")[-1]
            if not username:
                self.send_json({"error": "Username required"}, 400)
                return
            success, message = remove_user(username)
            status = 200 if success else 404
            self.send_json({"success": success, "message": message}, status)
        else:
            self.send_error(404)


if __name__ == "__main__":
    server = http.server.HTTPServer(("127.0.0.1", PORT), AdminHandler)
    print(f"Admin API server listening on port {PORT}")
    server.serve_forever()
