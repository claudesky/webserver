# Docker-Compose: NGINX + Certbot Webserver

An NGINX webserver with certbot service in docker-compose

Was made by following this article by pentacent: https://medium.com/@pentacent/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71

## Usage

### First Time Setup

Make a copy of the example .env file and enter the host domain and your email address (for certbot)

```bash
cp .env.example .env
vim .env
```

Run the initialization script

```bash
./init-letsencrypt.sh
```
