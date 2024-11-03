# Introduction

Keycloak with FIPS 140-2 compliant BouncyCastle docker image

# Develop
```
bash ./build.sh
```

TODO: document how to deploy/test/run the development image

# Deploy

This deployment section is for deploying the image to a docker swarm. The image
comes from the github actions built image on ghcr.io.

### make sure you can access ghcr.io/aardbeiplantje/iam/kc:latest

This is done via a classic personal access token:
```
export DOCKER_REGISTRY_PASS=...
printenv DOCKER_REGISTRY_PASS | docker login ghcr.io -u USERNAME --password-stdin
```

Now you can pull:
```
docker pull ghcr.io/aardbeiplantje/iam/kc:latest
```

### generate ipv6 network

Go to
[https://simpledns.plus/private-ipv6](https://simpledns.plus/private-ipv6) and
generate a random ipv6 address.

For example: fd53:5729:c558:8d8f::/64

### add ipv6 network, docker swarm doesn't allow to generate ipv6 via stack config
```
docker network create \
    --ipv6 \
    --subnet fd53:5729:c558:8d8f::/64 \
    --attachable=true \
    --scope=swarm \
    external_network_ipv6
```

### run deploy.sh
```
export STACK_NAME=iam_kc
export KC_HTTPS_SITE_KEY=auth_kc.key
export KC_HTTPS_SITE_CRT=auth_kc.crt
export DOCKER_REGISTRY_PASS
export DOCKER_REGISTRY=ghcr.io
export DOCKER_REGISTRY_USER=USERNAME
export DOCKER_REPOSITORY=aardbeiplantje/iam
export KC_ADMIN_USER=kcadmin
export KC_ADMIN_PASSWORD=...
export KC_HOSTNAME=auth.kc
export KC_HOSTNAME_PORT=443
export KC_POSTGRES_USER=kcuser
export KC_POSTGRES_PASSWORD=...
export KC_POSTGRES_DB=kcdb
bash ./deploy.sh
```
