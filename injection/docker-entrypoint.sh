#!/bin/sh
# vim: set noet :

set -eu

##############################################################################
# Waiting
##############################################################################

if [ "$1" = "cfssl" ] && [ "$2" = "serve" ]; then
	dockerize -timeout 30s -wait tcp://mysql:3306
fi

##############################################################################
# Initialization
##############################################################################

if [ ! -d "/etc/cfssl" ]; then
	mkdir -p "/etc/cfssl"
fi

cat > /etc/cfssl/db-config.json <<- __EOF__
{
  "driver": "mysql",
  "data_source": "cfssl:cfssl@tcp(mysql:3306)/cfssl?parseTime=true"
}
__EOF__

##############################################################################
# Configuration
##############################################################################

if [ "$1" = "cfssl" ] && [ "$2" = "serve" ]; then
	goose -dir /usr/local/share/cfssl/mysql mysql "cfssl:cfssl@tcp(mysql:3306)/cfssl?parseTime=true" up
fi

if [ -r "/run/secrets/cfssl_serve_ca" ]; then
	export CFSSL_SERVE_CA="$(cat /run/secrets/cfssl_serve_ca)"
fi

if [ -r "/run/secrets/cfssl_serve_ca_key" ]; then
	export CFSSL_SERVE_CA_KEY="$(cat /run/secrets/cfssl_serve_ca_key)"
fi

##############################################################################
# Arguments
##############################################################################

SERV_OPTS="${SERV_OPTS:-} -db-config=/etc/cfssl/db-config.json"
SERV_OPTS="${SERV_OPTS:-} -loglevel=${CFSSL_SERVE_LOG_LOVEL:-"1"}"
SERV_OPTS="${SERV_OPTS:-} -address=${CFSSL_SERVE_LISTEN_ADDR:-"0.0.0.0"}"
SERV_OPTS="${SERV_OPTS:-} -port=${CFSSL_SERVE_LISTEN_PORT:-"8888"}"
SERV_OPTS="${SERV_OPTS:-} -ca='env:CFSSL_SERVE_CA'"
SERV_OPTS="${SERV_OPTS:-} -ca-key='env:CFSSL_SERVE_CA_KEY'"

##############################################################################
# Service
##############################################################################

mkdir -p /etc/sv/cfssl

cat > /etc/sv/cfssl/run <<- __EOF__
#!/bin/sh
set -e
exec 2>&1
exec /usr/local/bin/cfssl serve ${SERV_OPTS}
__EOF__

chmod 0755 /etc/sv/cfssl/run

ln -s /etc/sv/cfssl /etc/service/cfssl

################################################################################
# Running
################################################################################

if [ "$1" = "cfssl" ] && [ "$2" = "serve" ]; then
	exec runsvdir /etc/service
else
	exec "$@"
fi
