#!/bin/bash

KC_ADMIN_USER=${KC_ADMIN_USER:-kcadmin}
KC_ADMIN_PASS=${KC_ADMIN_PASS?Need KC_ADMIN_PASS}
KC_HOSTNAME_PORT=${KC_HOSTNAME_PORT:-8443}
KC_HOSTNAME=${KC_HOSTNAME:-$HOSTNAME}

KC_BASE=https://$KC_HOSTNAME:$KC_HOSTNAME_PORT

function login(){
    curl -qsSLk --fail-with-body ${KC_BASE}/realms/master/protocol/openid-connect/token \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "username=$KC_ADMIN_USER" \
        --data-urlencode "password=$KC_ADMIN_PASS" \
        --data-urlencode "client_id=admin-cli" \
        --data-urlencode "grant_type=password" \
        || return $?
}

function get_realms(){
    local tkn=$1
    curl -qsSLk --fail-with-body ${KC_BASE}/admin/realms \
        -X GET \
        -H "Accept: application/json" \
        -H "Authorization: Bearer $tkn" \
        || return $?
}

function add_realm(){
    local tkn=$1
    local realm=$2
    curl -qsSLk --fail-with-body ${KC_BASE}/admin/realms \
        -X POST \
        -H "Accept: application/json" \
        -H "Authorization: Bearer $tkn" \
        -H "Content-Type: application/json" \
        -d "$realm" \
        || return $?
}

function get_clients(){
    local tkn=$1
    local realm=$2
    curl -qsSLk --fail-with-body ${KC_BASE}/admin/realms/$realm/clients \
        -X GET \
        -H "Accept: application/json" \
        -H "Authorization: Bearer $tkn" \
        || return $?
}

function add_client(){
    local tkn=$1
    local realm=$2
    local client=$3
    curl -qsSLk --fail-with-body ${KC_BASE}/admin/realms/$realm/clients \
        -X POST \
        -H "Accept: application/json" \
        -H "Authorization: Bearer $tkn" \
        -H "Content-Type: application/json" \
        -d "$client" \
        || return $?
}

function client_description_converter(){
    local tkn=$1
    local realm=$2
    local xmldata=$3
    curl -qsSLk --fail-with-body ${KC_BASE}/admin/realms/$realm/client-description-converter \
        -X POST \
        -H "Accept: application/json" \
        -H "Authorization: Bearer $tkn" \
        -H "Content-Type: application/xml" \
        -d "$xmldata" \
        || return $?
}


set -eu -o pipefail
login > "/tmp/kc_tkn" \
    || exit $?
tkn=$(jq -r .access_token < /tmp/kc_tkn)
realm_name=$(uuidgen)
add_realm "$tkn" '{"realm":"'"${realm_name}"'"}' \
    || exit $?
if [ ! -f /tmp/saml-metadata.xml ]; then
    curl -qsSLk https://signin.aws.amazon.com/static/saml-metadata.xml -o /tmp/saml-metadata.xml
fi
client_description_converter "$tkn" "${realm_name}" @/tmp/saml-metadata.xml \
    > /tmp/client-description-converter.json \
    || exit $?
add_client "$tkn" "${realm_name}" @/tmp/client-description-converter.json \
    || exit $?
get_clients "$tkn" "${realm_name}"|jq -r

