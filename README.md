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
    - `/public` - No authentication
    - `/restricted` - Authentication if specified (see below)

## Requirements

  - Requires a WebDav client.
  - I've found that not all clients are compatible (e.g., Dolphin doesn't work, but Thunar does). 

## Docker image information

### Docker image tags
  - `latest`: Latest version
  - `X.X.X`: [Semantic version](https://semver.org/) (use if you want to stick on a specific version)

### Environment variables
| Variable                   | Required?          | Definition                                                                                                     | Example                    | Comments                                                     |
|----------------------------|--------------------|----------------------------------------------------------------------------------------------------------------|----------------------------|--------------------------------------------------------------|
| WEBDAV_USER                | No                 | WebDav username                                                                                                | user                       | user AND pass need to be set for authentication to work      |
| WEBDAV_PASS                | No                 | WebDav password                                                                                                | password1                  | user AND pass need to be set for authentication to work      |
| NGINX_CLIENT_MAX_BODY_SIZE | No (default: 250M) | Nginx's [client_max_body_size](https://nginx.org/en/docs/http/ngx_http_core_module.html#client_max_body_size)  | 500M                       | Be sure to include the units. Set to `0` to disable.         |

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
      - WEBDAV_USER=user
      - WEBDAV_PASS=password1
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
