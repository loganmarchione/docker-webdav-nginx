# docker-webdav-nginx

[![CI/CD](https://github.com/loganmarchione/docker-webdav-nginx/actions/workflows/main.yml/badge.svg)](https://github.com/loganmarchione/docker-webdav-nginx/actions/workflows/main.yml)
[![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/loganmarchione/docker-webdav-nginx)](https://hub.docker.com/r/loganmarchione/docker-webdav-nginx)

Runs a Nginx WebDav server in Docker
  - Source code: [GitHub](https://github.com/loganmarchione/docker-webdav-nginx)
  - Docker container: [Docker Hub](https://hub.docker.com/r/loganmarchione/docker-webdav-nginx)
  - Image base: [Debian](https://hub.docker.com/_/debian)
  - Init system: N/A
  - Application: [Nginx](https://nginx.org/)
  - Architecture: `linux/amd64,linux/arm64,linux/arm/v7`

## Explanation

  - Runs a Nginx WebDav server in Docker.
  - Exposes WebDav locations
    - `http://localhost/public` - No authentication, open to all
    - `http://localhost/<username>` - Per-user directory, accessible only to the authenticated user matching `<username>` (requires `WEBDAV_USERS` to be set)
  - Includes an admin page at `http://localhost/admin` for runtime user management (add/remove users)
  - Serves a public signup page at `http://localhost/signup.html` (also `http://localhost/signup`) with no authentication

## Requirements

  - Requires a WebDav client.
  - I've found that not all clients are compatible (e.g., for me, Dolphin doesn't work, but Thunar does).
  - I prefer to use [Docker volumes](https://docs.docker.com/storage/volumes/) for storage, as [bind mounts](https://docs.docker.com/storage/bind-mounts/) might cause permissions issues when creating the required directories.

## Docker image information

### Docker image tags
  - `latest`: Latest version
  - `X.X.X`: [Semantic version](https://semver.org/) (use if you want to stick on a specific version)

### Environment variables
| Variable | Required? | Definition | Example | Comments |
|----------|-----------|------------|---------|----------|
| WEBDAV_USERS               | No                 | Comma-separated list of usernames/passwords, where each user-password pair is separated by a colon             | `user1:password1,user2:password2` | Usernames/passwords cannot contain commas `,`, colons `:`, spaces, or slashes `/`. Each user gets their own isolated directory at `/<username>`. |
| NGINX_CLIENT_MAX_BODY_SIZE | No (default: 250M) | Nginx's [client_max_body_size](https://nginx.org/en/docs/http/ngx_http_core_module.html#client_max_body_size)  | 500M                              | Be sure to include the units. Set to `0` to disable.                                                                           |
| ADMIN_USER                 | No (default: admin) | Username for the admin page                                                                                    | `admin`                           | Used to authenticate to the `/admin` page                                                                                      |
| ADMIN_PASS                 | Yes                 | Password for the admin page                                                                                    | `secretpass`                      | Required. No default is set to avoid insecure defaults.                                                                        |
| SIGNUP_HOST                | No (default: `https://www.google.com/`) | URL of your public signup page; users will be redirected to it. | `https://signup.example.com/` | Substituted into `signup.html` at container start. No auth required to reach the page. |

### Admin page

The admin page is available at `http://localhost/admin` and allows you to:
  - List all current WebDAV users
  - Add new users (creates credentials + directory + nginx config)
  - Remove existing users (deletes credentials + directory + files)

Users added or removed via the admin page are persisted in a `.users` file on the Docker volume and survive container restarts. The `WEBDAV_USERS` environment variable is only used as the initial seed when no `.users` file exists.

### Public signup page

The role of this page is simply to redirect to a public signup page hosted elsewhere.

The signup page (`signup.html` in this repo) is publicly accessible with no authentication at:
  - `http://localhost/signup.html`
  - `http://localhost/signup` (redirects to `/signup.html`)

The file is copied on the path `/var/www/webdav/signup.html` on every container start (the volume mount in docker-compose would otherwise shadow it). The `__SIGNUP_HOST__` placeholder in `signup.html` is replaced with the `SIGNUP_HOST` environment variable at that time. It is not WebDAV-writable and cannot be removed by WebDAV users.

### Ports
| Port on host              | Port in container | Comments            |
|---------------------------|-------------------|---------------------|
| Choose at your discretion | 80                | Nginx               |

### Volumes
| Volume on host            | Volume in container | Comments                           |
|---------------------------|---------------------|------------------------------------|
| Choose at your discretion | /var/www/webdav     | Used to store WebDav files         |

### Example usage
Below is an example docker-compose.yml file.
```
version: '3'
services:
  webdav:
    container_name: docker-webdav-nginx
    restart: unless-stopped
    environment:
      - WEBDAV_USERS=user1:password1,user2:password2
      - NGINX_CLIENT_MAX_BODY_SIZE=500M
      - ADMIN_USER=admin
      - ADMIN_PASS=changeme
    networks:
      - webdav
    ports:
      - '8888:80'
    volumes:
      - 'webdav:/var/www/webdav'
    image: loganmarchione/docker-webdav-nginx:latest

networks:
  webdav:

volumes:
  webdav:
    driver: local
```

### Debugging only

Below is an example of running locally (used to edit/test/debug).
```
# Build the Dockerfile
docker compose -f docker-compose-dev.yml up -d

# View logs
docker compose -f docker-compose-dev.yml logs -f

# Destroy when done
docker compose -f docker-compose-dev.yml down
```

Restart
> docker stop $(docker ps -a -q)
> docker rm $(docker ps -a -q)

# need to add a script to let people mount their own volume and make this path and password protected