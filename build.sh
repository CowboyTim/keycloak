#!/bin/bash 

APP_NAME=${APP_NAME:-kc}

set -eo pipefail

# where are we?
export WORKSPACE=${BASH_SOURCE%/*}

# make temp docker build dir
tmp_docker_build_dir=$(mktemp -p /tmp -d docker_build_XXXXXX)
mkdir -p $tmp_docker_build_dir/
cp -a $WORKSPACE/* $tmp_docker_build_dir/

# only for RHEL8/UBI8
if [ -d /etc/pki/entitlement/ ]; then
    mkdir -p $tmp_docker_build_dir/secrets
    cp -a /etc/yum.repos.d/redhat.repo /etc/pki/entitlement/ /etc/rhsm/ $tmp_docker_build_dir/secrets/
    mv $tmp_docker_build_dir/secrets/entitlement $tmp_docker_build_dir/secrets/etc-pki-entitlement
fi

# for a ubi8 container that already has secrets (from a RHEL8, in DinD)
if [ -d /run/secrets/etc-pki-entitlement ]; then
    mkdir -p $tmp_docker_build_dir/secrets
    cp -a /run/secrets/* $tmp_docker_build_dir/secrets/
fi

TAG_PREFIX=
if [ ! -z "$DOCKER_REGISTRY" -a ! -z "$DOCKER_REGISTRY_USER" -a ! -z "$DOCKER_REGISTRY_PASS" ]; then
    export DOCKER_REGISTRY_PASS DOCKER_REGISTRY_USER DOCKER_REGISTRY
    printenv DOCKER_REGISTRY_PASS \
        |docker login -u $DOCKER_REGISTRY_USER $DOCKER_REGISTRY --password-stdin
    DOCKER_REPOSITORY=${DOCKER_REPOSITORY:-registry}
    TAG_PREFIX=$DOCKER_REGISTRY/$DOCKER_REPOSITORY/
    do_push="--push"
    do_push="$do_push --cache-to   type=registry,ref=$TAG_PREFIX$APP_NAME-kc:buildcache,mode=max"
    do_push="$do_push --cache-from type=registry,ref=$TAG_PREFIX$APP_NAME-kc:buildcache"
else
    export DOCKER_REGISTRY=${DOCKER_REGISTRY:-local}
    export DOCKER_REPOSITORY=${DOCKER_REPOSITORY:-registry}
    TAG_PREFIX=${TAG_PREFIX:-${DOCKER_REGISTRY}/${DOCKER_REPOSITORY}/}
    do_push="--load"
fi

export BUILDX_CONFIG=${BUILDX_CONFIG:-~/.docker/buildx}
docker buildx use $APP_NAME-builder \
  || docker buildx create --name $APP_NAME-builder --use

# build/push docker
docker buildx build \
    --pull \
    --progress=plain \
    --tag local/$DOCKER_REPOSITORY/$APP_NAME:latest \
    --target kc \
    $tmp_docker_build_dir \
    --load \
        || exit $?

docker tag local/$DOCKER_REPOSITORY/$APP_NAME:latest $TAG_PREFIX$APP_NAME-kc:latest
docker push $TAG_PREFIX$APP_NAME-kc:latest
