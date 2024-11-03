#!/bin/bash 

APP_NAME=${APP_NAME:-iam}

set -eo pipefail

# where are we?
export WORKSPACE=${WORKSPACE:-${BASH_SOURCE%/*}}

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
    echo "doing docker login"
    printenv DOCKER_REGISTRY_PASS \
        |docker login -u $DOCKER_REGISTRY_USER $DOCKER_REGISTRY --password-stdin
    DOCKER_REPOSITORY=${DOCKER_REPOSITORY:-registry}
    TAG_PREFIX=$DOCKER_REGISTRY/$DOCKER_REPOSITORY/$APP_NAME
    export DOCKER_REGISTRY_PASS DOCKER_REGISTRY_USER DOCKER_REGISTRY DOCKER_REPOSITORY
else
    DOCKER_REGISTRY=${DOCKER_REGISTRY:-local}
    DOCKER_REPOSITORY=${DOCKER_REPOSITORY:-registry}
    TAG_PREFIX=$DOCKER_REGISTRY/$DOCKER_REPOSITORY/$APP_NAME
    export DOCKER_REGISTRY_PASS DOCKER_REGISTRY_USER DOCKER_REGISTRY DOCKER_REPOSITORY
fi

export BUILDX_CONFIG=${BUILDX_CONFIG:-~/.docker/buildx}
docker buildx use $APP_NAME-builder \
  || docker buildx create --name $APP_NAME-builder --use

for t in kc proxy; do
    # cache not working with ipv6 local not reachable from BuildKit
    do_cache=
    do_cache="$do_cache --cache-to   type=registry,ref=$TAG_PREFIX/$t:buildcache,mode=max"
    do_cache="$do_cache --cache-from type=registry,ref=$TAG_PREFIX/$t:buildcache"

    # run build
    docker buildx build \
        --network=host \
        --pull \
        --progress=plain \
        --tag local/$DOCKER_REPOSITORY/$APP_NAME/$t:latest \
        --target $t \
        --load \
        $tmp_docker_build_dir \
            || exit $?

    # tag + push, see comment above, --push won't work with BuildKit on ipv6 local
    docker tag local/$DOCKER_REPOSITORY/$APP_NAME/$t:latest $TAG_PREFIX/$t:latest \
        || exit $?
    docker push $TAG_PREFIX/$t:latest \
        || exit $?
done
