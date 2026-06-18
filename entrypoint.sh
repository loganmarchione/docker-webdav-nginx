#!/bin/bash -e

printf "########################################\n"
printf "# Container starting up!\n"
printf "########################################\n"

# Check for old WebDav user/pass settings, fail if they're still set
if [ -n "$WEBDAV_USER" ] && [ -n "$WEBDAV_PASS" ]; then
    printf "# ERROR: You're using the old WEBDAV_USER or WEBDAV_PASS env vars, read the docs to switch to the new WEBDAV_USERS env var\n"
    exit 1
fi

# Path to the nginx config file
NGINX_CONF=/etc/nginx/sites-enabled/webdav

# Directory for per-user htpasswd files
HTPASSWD_DIR=/etc/nginx/webdav_credentials
mkdir -p "$HTPASSWD_DIR"

# Generate an nginx location block for a single user.
# Each location uses its own htpasswd file containing only that user.
# This means:
#   - Unauthenticated requests → 401 (auth_basic challenge)
#   - Wrong user/password → 401 (auth_basic rejection)
#   - Correct user → 200 (access granted)
# Usage: generate_user_location_block <username> <htpasswd_dir>
generate_user_location_block() {
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
if [ ! -z "$WEBDAV_USERS" ]; then
    # Split users by comma
    IFS=',' read -ra USERS <<< "$WEBDAV_USERS"
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
else
    printf "# WARN:  No WebDav user/pass were set, no per-user directories will be created\n"
fi

# Replace the placeholder in the nginx config with generated user location blocks
NGINX_CONF_TMP="${NGINX_CONF}.tmp"
awk -v replacements="$USER_LOCATIONS" '
    /### USER_LOCATIONS ###/ { printf "%s\n", replacements; next }
    { print }
' "$NGINX_CONF" > "$NGINX_CONF_TMP"
mv "$NGINX_CONF_TMP" "$NGINX_CONF"

# Check for client_max_body_size setting
if [ -n "$NGINX_CLIENT_MAX_BODY_SIZE" ]; then
    printf "# STATE: Setting client_max_body_size to $NGINX_CLIENT_MAX_BODY_SIZE\n"
    sed -i "s/client_max_body_size 250M;/client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;/g" "$NGINX_CONF"
fi

printf "# STATE: Nginx is starting up now, the logs you see below are error_log and access_log from Nginx\n"
exec "$@"
