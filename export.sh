#!/bin/bash
KC_HOSTNAME=${KC_HOSTNAME?Need keycloak hostname KC_HOSTNAME}
KC_REALM=${KC_REALM:-master}
KC_HOSTNAME_PORT=${KC_HOSTNAME_PORT:-443}
KC_ADMIN_USER=${KC_ADMIN_USER?Keycloak admin user KC_ADMIN_USER}
function read_pass(){
    nm="$1"
    de="$2"
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
read_pass \
    KC_ADMIN_PASS \
    "Keycloak admin user password for <$KC_HOSTNAME:$KC_HOSTNAME_PORT>"
KC_URL="https://${KC_HOSTNAME}:${KC_HOSTNAME_PORT}"
curl_cmd="curl -qsSLkf"
tkn=$($curl_cmd \
    -XPOST \
    $KC_URL/realms/${KC_REALM}/protocol/openid-connect/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$KC_ADMIN_USER" \
    -d "password=$KC_ADMIN_PASS" \
    -d "client_id=admin-cli" \
    -d "grant_type=password")
a_tkn=$(echo "$tkn"|jq -r '.access_token')

$curl_cmd -XGET \
    "${KC_URL}/admin/realms/${KC_REALM}" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${a_tkn}"|jq -r
