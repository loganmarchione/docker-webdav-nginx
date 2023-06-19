#!/bin/sh -e

printf "########################################\n"
printf "# Container starting up!\n"
printf "########################################\n"

# Check for WebDav user/pass
printf "# STATE: Checking for WebDav user/pass\n"
if [ -n "$WEBDAV_USER" ] && [ -n "$WEBDAV_PASS" ]
then
	printf "# STATE: WebDav user/pass written to /etc/nginx/webdav_credentials\n"
	htpasswd -b -c /etc/nginx/webdav_credentials $WEBDAV_USER $WEBDAV_PASS > /dev/null 2>&1
else
	printf "# WARN:  No WebDav user/pass were set, the "restricted" directory has no authentication on it!\n"
	sed -i "s/.*auth_basic.*//g" /etc/nginx/sites-enabled/webdav
	sed -i "s/.*auth_basic_user_file.*//g" /etc/nginx/sites-enabled/webdav
fi

# Check for client_max_body_size setting
if [ -n "$NGINX_CLIENT_MAX_BODY_SIZE" ]
then
	printf "# STATE: Setting client_max_body_size to $NGINX_CLIENT_MAX_BODY_SIZE\n"
	sed -i "s/client_max_body_size 250M;/client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;/g" /etc/nginx/sites-enabled/webdav
fi

printf "# STATE: Nginx is starting up now, the logs you see below are error_log and access_log from Nginx\n"
exec "$@"
