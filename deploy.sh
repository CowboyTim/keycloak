#!/bin/bash 
export STACK_NAME=${STACK_NAME?Need STACK_NAME}
export STACK_FILE=${STACK_FILE:-kc.yml}
export DOCKER_REGISTRY=${DOCKER_REGISTRY?Need DOCKER_REGISTRY}
export DOCKER_REPOSITORY=${DOCKER_REPOSITORY?Need DOCKER_REPOSITORY}
export WORKSPACE=${WORKSPACE:-${BASH_SOURCE%/*}}
export CFG_PREFIX=$STACK_NAME-$(date +%s)

export KC_HTTPS_SITE_KEY=${KC_HTTPS_SITE_KEY?Need HTTPS key}
export KC_HTTPS_SITE_CRT=${KC_HTTPS_SITE_CRT?Need HTTPS crt}
export IAM_PROXY_HTTPS_SITE_KEY=${IAM_PROXY_HTTPS_SITE_KEY?Need HTTPS key}
export IAM_PROXY_HTTPS_SITE_CRT=${IAM_PROXY_HTTPS_SITE_CRT?Need HTTPS crt}

export PROXY_EXTERNAL_PORT=${PROXY_EXTERNAL_PORT:-443}
export PROXY_INTERNAL_PORT=${PROXY_INTERNAL_PORT:-8443}
export KC_HOSTNAME=${KC_HOSTNAME:-$HOSTNAME}

export APP_NAME=${APP_NAME:-iam}

echo $KC_HTTPS_KEY_STORE_PASSWORD
function read_pass(){
    local nm="$1"
    local de="$2"
    while [ -z "${!nm}" ]; do
        echo -n "$de: "
        read -s $nm
        echo
        if [ -z "${!nm}" ]; then
            continue
        fi
    done
    export $nm
}

read_pass KC_HTTPS_KEY_STORE_PASSWORD \
    "Keycloak HTTPS keystore password for <$KC_HOSTNAME>"

export KC_ADMIN_USER=${KC_ADMIN_USER:-kcadmin}
read_pass KC_ADMIN_PASS \
    "Keycloak password for <$KC_ADMIN_USER@$KC_HOSTNAME>"

export KC_POSTGRES_USER=${KC_POSTGRES_USER:-kcuser}
export KC_POSTGRES_DB=${KC_POSTGRES_DB:-kcdb}
read_pass KC_POSTGRES_PASSWORD \
    "Keycloak postgres DB password <$KC_POSTGRES_USER@$KC_POSTGRES_DB>"

cat "$KC_HTTPS_SITE_KEY"|docker secret create \
    kc-site.key-$CFG_PREFIX \
    -
cat "$KC_HTTPS_SITE_CRT"|docker secret create \
    kc-site.crt-$CFG_PREFIX \
    -
cat "$IAM_PROXY_HTTPS_SITE_KEY"|docker secret create \
    iam-proxy-https-key-$CFG_PREFIX \
    -
cat "$IAM_PROXY_HTTPS_SITE_CRT"|docker secret create \
    iam-proxy-https-crt-$CFG_PREFIX \
    -

JWT_SECRET=${JWT_SECRET:-$WORKSPACE/.jwt_secret}
if [ ! -s $JWT_SECRET ]; then
    openssl rand 32|base64|tr '+/' '-_'|tr -d '=' > $JWT_SECRET
fi
JWT_KEY_FILE=${JWT_KEY_FILE:-$WORKSPACE/.jwt_key}
JWK_KID=${JWK_KID:-$(uuidgen)}
cat >$JWT_KEY_FILE <<EOF
{"keys":[{"kty":"oct","kid":"$JWK_KID","k":"$(cat $JWT_SECRET)"}]}
EOF
JWT_APP_SCOPE=${JWT_APP_SCOPE:-$APP_NAME}
export JWT_KEY_FILE JWK_KID JWT_APP_SCOPE
docker secret create \
    --template-driver golang \
    api-jwk-$CFG_PREFIX \
    $JWT_KEY_FILE

docker stack deploy \
    -c $WORKSPACE/$STACK_FILE \
    --with-registry-auth \
    --detach=false \
    $STACK_NAME
