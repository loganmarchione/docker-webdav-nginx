# docker-webdav-nginx

[![CI/CD](https://github.com/loganmarchione/docker-webdav-nginx/actions/workflows/main.yml/badge.svg)](https://github.com/loganmarchione/docker-webdav-nginx/actions/workflows/main.yml)
[![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/loganmarchione/docker-webdav-nginx)](https://hub.docker.com/r/loganmarchione/docker-webdav-nginx)

Runs a Nginx WebDav server in Docker
  - Source code: [GitHub](https://github.com/loganmarchione/docker-webdav-nginx)
  - Docker container: [Docker Hub](https://hub.docker.com/r/loganmarchione/docker-webdav-nginx)
  - Image base: [Ubuntu](https://hub.docker.com/_/ubuntu)
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
| Variable    | Required? | Definition                       | Example                    | Comments                                                     |
|-------------|-----------|----------------------------------|----------------------------|--------------------------------------------------------------|
| WEBDAV_USER | No        | WebDav username                  | user                       | user AND pass need to be set for authentication to work      |
| WEBDAV_PASS | No        | WebDav password                  | password1                  | user AND pass need to be set for authentication to work      |

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
    container_name: webdav
    restart: unless-stopped
    environment:
      - WEBDAV_USER=user
      - WEBDAV_PASS=password1
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

## TODO
