1. Introduction

Keycloak with FIPS 140-2 compliant BouncyCastle docker image

2. to develop:
```
bash ./build.sh
```

3. to deploy:

# make sure you can access ghcr.io/aardbeiplantje/iam/kc:latest

This is done via a classic personal access token:
```
export DOCKER_REGISTRY_PASS=...
printenv DOCKER_REGISTRY_PASS | docker login ghcr.io -u USERNAME --password-stdin
```

Now you can pull:
```
docker pull ghcr.io/aardbeiplantje/iam/kc:latest
```

# run deploy.sh
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
