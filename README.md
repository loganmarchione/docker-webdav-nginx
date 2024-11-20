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
  - Exposes two WebDav locations
    - `http://localhost/public` - No authentication
    - `http://localhost/restricted` - Authentication if specified (see below)

## Requirements

  - Requires a WebDav client.
  - I've found that not all clients are compatible (e.g., for me, Dolphin doesn't work, but Thunar does).
  - I prefer to use [Docker volumes](https://docs.docker.com/storage/volumes/) for storage, as [bind mounts](https://docs.docker.com/storage/bind-mounts/) might cause permissions issues when creating the required directories.

## Docker image information

### Docker image tags
  - `latest`: Latest version
  - `X.X.X`: [Semantic version](https://semver.org/) (use if you want to stick on a specific version)

### Environment variables
| Variable                   | Required?          | Definition                                                                                                     | Example                           | Comments                                                                                                                       |
|----------------------------|--------------------|----------------------------------------------------------------------------------------------------------------|-----------------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| WEBDAV_USERS               | No                 | Comma-separated list of usernames/passwords, where each user-password pair is separated by a colon             | `user1:password1,user2:password2` | Usernames/passwords cannot contain commas `,` or colons `:` and all users share the same location for files (i.e., `/restricted`) |
| NGINX_CLIENT_MAX_BODY_SIZE | No (default: 250M) | Nginx's [client_max_body_size](https://nginx.org/en/docs/http/ngx_http_core_module.html#client_max_body_size)  | 500M                              | Be sure to include the units. Set to `0` to disable.                                                                           |

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

Below is an example of running locally (used to edit/test/debug).
```
# Build the Dockerfile
docker compose -f docker-compose-dev.yml up -d

# View logs
docker compose -f docker-compose-dev.yml logs -f

# Destroy when done
docker compose -f docker-compose-dev.yml down
```

## TODO
