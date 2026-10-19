#!/bin/bash -e

printf "########################################\n"
printf "# Container starting up!\n"
printf "########################################\n"

NGINX_CONF=/etc/nginx/sites-enabled/webdav

# Directory for per-user htpasswd files
HTPASSWD_DIR=/etc/nginx/webdav_credentials
mkdir -p "$HTPASSWD_DIR"

# Persistent users file on the mounted volume
USERS_FILE=/var/www/webdav/.users

# ── Install public signup page ─────────────────────────────────────────────────────
# Must be copied to /var/www/webdav at every start since the data volume is mounted at the same path which shadows all pre-exising files.
SIGNUP_SRC=/opt/signup.html
SIGNUP_DST=/var/www/webdav/signup.html
if [ -f "$SIGNUP_SRC" ]; then
    SIGNUP_URL="${SIGNUP_HOST:-https://www.google.com/}"
    SIGNUP_URL="${SIGNUP_URL%\"}"
    SIGNUP_URL="${SIGNUP_URL#\"}"
    # Escape specials chars prior to sed replacement: \ & |
    SIGNUP_URL_SED=$(printf '%s' "$SIGNUP_URL" | sed 's/[\\&|]/\\&/g')
    sed "s|__SIGNUP_HOST__|${SIGNUP_URL_SED}|g" "$SIGNUP_SRC" > "$SIGNUP_DST"

    chown www-data:www-data "$SIGNUP_DST"
    chmod 644 "$SIGNUP_DST"
    printf "# STATE: Public signup page installed at /signup.html (redirect → %s)\n" "$SIGNUP_URL"
else
    printf "# WARN:  $SIGNUP_SRC not found, public signup page will be unavailable\n"
fi


# ── Generate admin credentials ───────────────────────────────────────────────
ADMIN_USER="${ADMIN_USER:-admin}"
if [ -z "$ADMIN_PASS" ]; then
    printf "# ERROR: ADMIN_PASS environment variable is required\n"
    exit 1
else
    htpasswd -bc /etc/nginx/webdav_credentials_admin "$ADMIN_USER" "$ADMIN_PASS" > /dev/null 2>&1
    printf "# STATE: Admin credentials created for user: $ADMIN_USER\n"
fi

# ── Generate admin location block in nginx config ─────────────────────────────
ADMIN_LOCATION='  location /admin {
    auth_basic             "Admin";
    auth_basic_user_file   /etc/nginx/webdav_credentials_admin;

    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }'


# ── Load user state ──────────────────────────────────────────────────────────
# Priority: .users file on volume > WEBDAV_USERS env var
if [ -f "$USERS_FILE" ]; then
    printf "# STATE: Loading users from $USERS_FILE\n"
    WEBDAV_USERS_FROM_FILE=$(cat "$USERS_FILE" | tr '\n' ',' | sed 's/,$//')
    WEBDAV_SOURCE="$WEBDAV_USERS_FROM_FILE"
else
    printf "# STATE: No .users file found, using WEBDAV_USERS env var\n"
    WEBDAV_SOURCE="$WEBDAV_USERS"
fi

# ── Generate nginx location blocks for each user ─────────────────────────────

generate_user_location_block() {
    # Generate an nginx location block for a single user.
    # Each location uses its own htpasswd file containing only that user.
    # This means:
    #   - Unauthenticated requests → 401 (auth_basic challenge)
    #   - Wrong user/password → 401 (auth_basic rejection)
    #   - Correct user → 200 (access granted)
    # Usage: generate_user_location_block <username> <htpasswd_dir>
    
    local username="$1"
    local htpasswd_dir="$2"

    cat <<EOF

  location /${username} {
    auth_basic             "Restricted";
    auth_basic_user_file   ${htpasswd_dir}/${username};

    dav_methods            PUT DELETE MKCOL COPY MOVE;
    dav_ext_methods        PROPFIND OPTIONS;
    dav_access             user:rw group:rw;

    create_full_put_path   on;

    error_log              /dev/stdout;
    access_log             /dev/stdout;

    # Handle CORS preflight before auth runs
    if (\$request_method = 'OPTIONS') {
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
EOF
}

# Variable to accumulate per-user location blocks
USER_LOCATIONS=""

# Check for WebDav user/pass
printf "# STATE: Checking for WebDav user/pass\n"
if [ ! -z "$WEBDAV_SOURCE" ]; then
    # Split users by comma
    IFS=',' read -ra USERS <<< "$WEBDAV_SOURCE"
    for USER in "${USERS[@]}"; do
        # Split username and password by colon
        IFS=':' read -ra CREDENTIALS <<< "$USER"
        USERNAME=${CREDENTIALS[0]}
        PASSWORD=${CREDENTIALS[1]}

        # Create per-user htpasswd file (only this user can authenticate)
        HTPASSWD_FILE="${HTPASSWD_DIR}/${USERNAME}"
        htpasswd -bc "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD" > /dev/null 2>&1
        printf "# STATE: WebDav credentials written to $HTPASSWD_FILE\n"

        # Create per-user directory
        mkdir -p "/var/www/webdav/$USERNAME"
        chown www-data:www-data "/var/www/webdav/$USERNAME"
        printf "# STATE: Created directory for user: $USERNAME\n"

        # Append nginx location block for this user
        USER_LOCATIONS="${USER_LOCATIONS}$(generate_user_location_block "$USERNAME" "$HTPASSWD_DIR")"
    done

    # Persist users to .users file (if not already loaded from it)
    if [ ! -f "$USERS_FILE" ]; then
        printf "%s\n" "${USERS[@]}" > "$USERS_FILE"
        printf "# STATE: Persisted users to $USERS_FILE\n"
    fi
else
    printf "# WARN:  No WebDav user/pass were set, no per-user directories will be created\n"
fi

# ── Inject generated blocks into nginx config ────────────────────────────────
NGINX_CONF_TMP="${NGINX_CONF}.tmp"
awk -v admin_block="$ADMIN_LOCATION" -v user_blocks="$USER_LOCATIONS" '
    /### ADMIN_LOCATION ###/ { printf "%s\n", admin_block; next }
    /### USER_LOCATIONS ###/ { printf "%s\n", user_blocks; next }
    { print }
' "$NGINX_CONF" > "$NGINX_CONF_TMP"
mv "$NGINX_CONF_TMP" "$NGINX_CONF"

# Check for client_max_body_size setting
if [ -n "$NGINX_CLIENT_MAX_BODY_SIZE" ]; then
    printf "# STATE: Setting client_max_body_size to $NGINX_CLIENT_MAX_BODY_SIZE\n"
    sed -i "s/client_max_body_size 250M;/client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;/g" "$NGINX_CONF"
fi

# ── Start the admin API server ───────────────────────────────────────────────
printf "# STATE: Starting admin API server on port 8080\n"
python3 /opt/admin/admin_api.py &

printf "# STATE: Nginx is starting up now, the logs you see below are error_log and access_log from Nginx\n"
exec "$@"
