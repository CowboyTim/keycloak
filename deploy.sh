#!/bin/bash 
set -e
export STACK_NAME=${STACK_NAME?Need STACK_NAME}
export STACK_FILE=${STACK_FILE:-kc.yml}
export DOCKER_REGISTRY=${DOCKER_REGISTRY?Need DOCKER_REGISTRY}
export DOCKER_REPOSITORY=${DOCKER_REPOSITORY?Need DOCKER_REPOSITORY}
export WORKSPACE=${WORKSPACE:-$(dirname $(readlink -f $BASH_SOURCE))}
export CFG_PREFIX=$STACK_NAME-$(date +%s)

export KC_HTTPS_SITE_KEY=${KC_HTTPS_SITE_KEY?Need HTTPS key}
export KC_HTTPS_SITE_CRT=${KC_HTTPS_SITE_CRT?Need HTTPS crt}

export KC_HOSTNAME_PORT=${KC_HOSTNAME_PORT:-443}
export KC_HOSTNAME=${KC_HOSTNAME:-$HOSTNAME}

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
    "Keycloak HTTPS keystore password for <$KC_HOSTNAME:$KC_HOSTNAME_PORT>"

export KC_ADMIN_USER=${KC_ADMIN_USER:-kcadmin}
read_pass KC_ADMIN_PASS \
    "Keycloak password for <$KC_ADMIN_USER@$KC_HOSTNAME:$KC_HOSTNAME_PORT>"

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

docker stack deploy \
    -c $WORKSPACE/$STACK_FILE \
    --with-registry-auth \
    --detach=false \
    $STACK_NAME
