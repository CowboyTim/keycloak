#!/bin/bash

set -x

# see https://www.keycloak.org/server/all-config

export KEYCLOAK_HOME=/opt/keycloak

export KC_DB=postgres
export KC_HOSTNAME=${KC_HOSTNAME:-keycloak.fed.local}
export KC_HOSTNAME_STRICT=${KC_HOSTNAME_STRICT:-false}
export KC_CACHE=${KC_CACHE:-local}
export JAVA_OPTS_APPEND=${JAVA_OPTS_APPEND:-"-Djava.security.properties=$KEYCLOAK_HOME/conf/kc.java.security -Djava.security.egd=file:/dev/urandom -Dquarkus.transaction-manager.enable-recovery=true"}
export KC_HTTP_ENABLED=${KC_HTTP_ENABLED:-false}
export KC_HTTPS_PORT=${KC_HTTPS_PORT:-8443}
export KC_HTTPS_PROTOCOLS=${KC_HTTPS_PROTOCOLS:-TLSv1.3}
export KC_HTTPS_CERTIFICATE_FILE=/run/secrets/$KC_HOSTNAME.crt
export KC_HTTPS_CERTIFICATE_KEY_FILE=/run/secrets/$KC_HOSTNAME.key
export KC_HTTPS_KEY_STORE_FILE=$KEYCLOAK_HOME/conf/server.keystore
export KC_HTTPS_KEY_STORE_TYPE=BCFKS
export KC_FIPS_MODE=${KC_FIPS_MODE:-strict}
export KC_HOSTNAME_STRICT_HTTPS=${KC_HOSTNAME_STRICT_HTTPS:-false}
export KC_FEATURES=${KC_FEATURES:-token-exchange,fips,kerberos,preview,authorization,impersonation,web-authn,oid4vc-vci,admin,admin-api,organization,recovery-codes,persistent-user-sessions,client-secret-rotation,docker,admin-fine-grained-authz,scripts,step-up-authentication,token-exchange,transient-users,update-email,web-authn}
export KC_TRANSACTION_XA_ENABLED=${KC_TRANSACTION_XA_ENABLED:-true}

# bcfips
export JAVA_OPTIONS=${JAVA_OPTS:-"-Xms256m -Xmx1024m -XX:MetaspaceSize=96M -XX:MaxMetaspaceSize=256m"}
echo "securerandom.strongAlgorithms=PKCS11:SunPKCS11-NSS-FIPS" > /tmp/kc.keystore-create.java.security
_JAVA_OPTIONS="-Djava.security.properties=/tmp/kc.keystore-create.java.security -Djava.security.egd=file:/dev/urandom $JAVA_OPTIONS" \
export _JAVA_OPTIONS
keytool \
    -genkeypair \
    -storepass "$KC_HTTPS_KEY_STORE_PASSWORD" \
    -storetype bcfks \
    -providername BCFIPS \
    -providerclass org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider \
    -provider org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider \
    -providerpath $KEYCLOAK_HOME/providers/bc-fips-*.jar \
    -sigalg SHA512withRSA \
    -keyalg RSA \
    -keysize 2048 \
    -dname "CN=$KC_HOSTNAME" \
    -alias "$KC_HOSTNAME" \
    -ext "SAN:c=DNS:$KC_HOSTNAME" \
    -keystore $KEYCLOAK_HOME/conf/server.keystore \
    -noprompt

export PATH=$KEYCLOAK_HOME/bin:$PATH
$KEYCLOAK_HOME/bin/kc.sh build
$KEYCLOAK_HOME/bin/kc.sh show-config
exec bash $KEYCLOAK_HOME/bin/kc.sh start \
    --optimized \
    --spi-sticky-session-encoder-infinispan-should-attach-route=false \
    --proxy-headers xforwarded \
    --log-level=DEBUG,org.keycloak.common.crypto:TRACE,org.keycloak.crypto:TRACE \
    --verbose
