#!/bin/bash -e

printf "########################################\n"
printf "# Container starting up!\n"
printf "########################################\n"

# Check for old WebDav user/pass settings, fail if they're still set
if [ -n "$WEBDAV_USER" ] && [ -n "$WEBDAV_PASS" ]; then
    printf "# ERROR: You're using the old WEBDAV_USER or WEBDAV_PASS env vars, read the docs to switch to the new WEBDAV_USERS env var\n"
    exit 1
fi

# Path to the htpasswd file
HTPASSWD_FILE=/etc/nginx/webdav_credentials

# Ensure the file exists or clear existing content
> "$HTPASSWD_FILE"

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

        # Add user to htpasswd file
        htpasswd -b "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD" > /dev/null 2>&1
		printf "# STATE: WebDav user/pass written to $HTPASSWD_FILE\n"
    done
else
	printf "# WARN:  No WebDav user/pass were set, the "restricted" directory has no authentication on it!\n"
	sed -i "s/.*auth_basic.*//g" /etc/nginx/sites-enabled/webdav
	sed -i "s/.*auth_basic_user_file.*//g" /etc/nginx/sites-enabled/webdav
fi

# Check for client_max_body_size setting
if [ -n "$NGINX_CLIENT_MAX_BODY_SIZE" ]; then
	printf "# STATE: Setting client_max_body_size to $NGINX_CLIENT_MAX_BODY_SIZE\n"
	sed -i "s/client_max_body_size 250M;/client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;/g" /etc/nginx/sites-enabled/webdav
fi

printf "# STATE: Nginx is starting up now, the logs you see below are error_log and access_log from Nginx\n"
exec "$@"
