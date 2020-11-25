#!/bin/sh
# vim: set noet :

set -eu

##############################################################################
# Initialization
##############################################################################

if [ ! -d "/etc/cfssl" ]; then
	mkdir -p "/etc/cfssl"
fi

##############################################################################
# Configuration
##############################################################################

if [ -n "${CFSSL_CONFIG_JSON:-}" ]; then
	echo "${CFSSL_CONFIG_JSON}" > "/etc/cfssl/config.json"
else
	if [ ! -f "/etc/cfssl/config.json" ]; then
		echo 'Generate /etc/cfssl/config.json'

		cat > "/etc/cfssl/config.json" <<- __EOF__
		{
			"signing": {
				"default": {
					"expiry": "8760h",
					"crl_url": "http://localhost:8888/crl",
					"ocsp_url": "http://localhost:8889",
					"usages": [
						"signing",
						"key encipherment",
						"client auth"
					]
				},
				"profiles": {
					"ocsp": {
						"usages": ["digital signature", "ocsp signing"],
						"expiry": "8760h"
					},
					"intermediate": {
						"usages": ["cert sign", "crl sign"],
						"expiry": "8760h",
						"ca_constraint": {"is_ca": true}
					},
					"server": {
						"usages": ["signing", "key encipherment", "server auth"],
						"expiry": "8760h"
					},
					"client": {
						"usages": ["signing", "key encipherment", "client auth"],
						"expiry": "8760h"
					}
				}
			}
		}
		__EOF__
	fi
fi

if [ -n "${CFSSL_ROOT_CA_CSR_JSON:-}" ]; then
	echo "${CFSSL_ROOT_CA_CSR_JSON}" > "/etc/cfssl/root-ca-csr.json"
else
	if [ ! -f "/etc/cfssl/root-ca-csr.json" ]; then
		echo 'Generate /etc/cfssl/root-ca-csr.json'

		cat > "/etc/cfssl/root-ca-csr.json" <<- __EOF__
		{
			"CN": "Root CA",
			"key": {
				"algo": "ecdsa",
				"size": 256
			},
			"names": [
				{
					"O": "CFSSL"
				}
			]
		}
		__EOF__
	fi
fi

if [ -n "${CFSSL_LOWER_CA_CSR_JSON:-}" ]; then
	echo "${CFSSL_LOWER_CA_CSR_JSON}" > "/etc/cfssl/lower-ca-csr.json"
else
	if [ ! -f "/etc/cfssl/lower-ca-csr.json" ]; then
		echo 'Generate /etc/cfssl/lower-ca-csr.json'

		cat > "/etc/cfssl/lower-ca-csr.json" <<- __EOF__
		{
			"CN": "Intermediate CA",
			"key": {
				"algo": "ecdsa",
				"size": 256
			},
			"names": [
				{
					"O": "CFSSL"
				}
			]
		}
		__EOF__
	fi
fi

if [ -n "${CFSSL_OCSP_CA_CSR_JSON:-}" ]; then
	echo "${CFSSL_OCSP_CA_CSR_JSON}" > "/etc/cfssl/lower-ocsp-csr.json"
else
	if [ ! -f "/etc/cfssl/lower-ocsp-csr.json" ]; then
		echo 'Generate /etc/cfssl/lower-ocsp-csr.json'

		cat > "/etc/cfssl/lower-ocsp-csr.json" <<- __EOF__
		{
			"CN": "OCSP Responder",
			"key": {
				"algo": "ecdsa",
				"size": 256
			},
			"names": [
				{
					"O": "CFSSL"
				}
			]
		}
		__EOF__
	fi
fi

##############################################################################
# Root CA
##############################################################################

if [ -z "${CFSSL_ROOT_CA_CRT_PEM:-}" ] || [ -z "${CFSSL_ROOT_CA_KEY_PEM:-}" ]; then
	cfssl gencert -initca "/etc/cfssl/root-ca-csr.json" | cfssljson -bare -stdout > "/tmp/cfssl"

	awk '/^-----BEGIN CERTIFICATE-----$/,/^-----END CERTIFICATE-----$/' "/tmp/cfssl" > "/etc/cfssl/root-ca-crt.pem"
	awk '/^-----BEGIN .* PRIVATE KEY-----$/,/^-----END .* PRIVATE KEY-----$/' "/tmp/cfssl" > "/etc/cfssl/root-ca-key.pem"
	awk '/^-----BEGIN CERTIFICATE REQUEST-----$/,/^-----END CERTIFICATE REQUEST-----$/' "/tmp/cfssl" > "/etc/cfssl/root-ca-csr.pem"

	rm "/tmp/cfssl"
else
	echo "${CFSSL_ROOT_CA_CRT_PEM}" > "/etc/cfssl/root-ca-crt.pem"
	echo "${CFSSL_ROOT_CA_KEY_PEM}" > "/etc/cfssl/root-ca-key.pem"
fi

##############################################################################
# Intermidiate CA
##############################################################################

if [ -z "${CFSSL_LOWER_CA_CRT_PEM:-}" ] || [ -z "${CFSSL_LOWER_CA_KEY_PEM:-}" ]; then
	cfssl gencert \
		-ca="/etc/cfssl/root-ca-crt.pem" \
		-ca-key="/etc/cfssl/root-ca-key.pem" \
		-config="/etc/cfssl/config.json" \
		-profile="intermediate" \
		"/etc/cfssl/lower-ca-csr.json" \
		| cfssljson -bare -stdout > "/tmp/cfssl"

	awk '/^-----BEGIN CERTIFICATE-----$/,/^-----END CERTIFICATE-----$/' "/tmp/cfssl" > "/etc/cfssl/lower-ca-crt.pem"
	awk '/^-----BEGIN .* PRIVATE KEY-----$/,/^-----END .* PRIVATE KEY-----$/' "/tmp/cfssl" > "/etc/cfssl/lower-ca-key.pem"
	awk '/^-----BEGIN CERTIFICATE REQUEST-----$/,/^-----END CERTIFICATE REQUEST-----$/' "/tmp/cfssl" > "/etc/cfssl/lower-ca-csr.pem"

	rm "/tmp/cfssl"
else
	echo "${CFSSL_LOWER_CA_CRT_PEM}" > "/etc/cfssl/lower-ca-crt.pem"
	echo "${CFSSL_LOWER_CA_KEY_PEM}" > "/etc/cfssl/lower-ca-key.pem"
fi

##############################################################################
# OCSP Responder
##############################################################################

if [ -z "${CFSSL_OCSP_CA_CRT_PEM:-}" ] || [ -z "${CFSSL_OCSP_CA_KEY_PEM:-}" ]; then
	cfssl gencert \
		-ca="/etc/cfssl/lower-ca-crt.pem" \
		-ca-key="/etc/cfssl/lower-ca-key.pem" \
		-config="/etc/cfssl/config.json" \
		-profile="ocsp" \
		"/etc/cfssl/lower-ocsp-csr.json" \
		| cfssljson -bare -stdout > "/tmp/cfssl"

	awk '/^-----BEGIN CERTIFICATE-----$/,/^-----END CERTIFICATE-----$/' "/tmp/cfssl" > "/etc/cfssl/lower-ocsp-crt.pem"
	awk '/^-----BEGIN .* PRIVATE KEY-----$/,/^-----END .* PRIVATE KEY-----$/' "/tmp/cfssl" > "/etc/cfssl/lower-ocsp-key.pem"
	awk '/^-----BEGIN CERTIFICATE REQUEST-----$/,/^-----END CERTIFICATE REQUEST-----$/' "/tmp/cfssl" > "/etc/cfssl/lower-ocsp-csr.pem"

	rm "/tmp/cfssl"
else
	echo "${CFSSL_OCSP_CA_CRT_PEM}" > "/etc/cfssl/lower-ocsp-crt.pem"
	echo "${CFSSL_OCSP_CA_KEY_PEM}" > "/etc/cfssl/lower-ocsp-key.pem"
fi

##############################################################################
# Databases
##############################################################################

if [ "${CFSSL_CERTDB_TYPE}" = "mysql" ]; then
	cat > "/etc/cfssl/db-config.json" <<- __EOF__
	{
		"driver": "${CFSSL_CERTDB_TYPE}",
		"data_source": "${CFSSL_CERTDB_USER}:${CFSSL_CERTDB_PASS}@tcp(${CFSSL_CERTDB_HOST}:${CFSSL_CERTDB_PORT})/${CFSSL_CERTDB_NAME}?parseTime=true"
	}
	__EOF__

	{
		echo "production:"
		echo "  driver: ${CFSSL_CERTDB_TYPE}"
		echo "  open: ${CFSSL_CERTDB_USER}:${CFSSL_CERTDB_PASS}@tcp(${CFSSL_CERTDB_HOST}:${CFSSL_CERTDB_PORT})/${CFSSL_CERTDB_NAME}?parseTime=true"
	} > "/usr/local/share/cfssl/${CFSSL_CERTDB_TYPE}/dbconf.yml"

	dockerize -timeout 30s -wait "tcp://${CFSSL_CERTDB_HOST}:${CFSSL_CERTDB_PORT}"
	goose -env "production" -path "/usr/local/share/cfssl/${CFSSL_CERTDB_TYPE}" up
fi

##############################################################################
# Service
##############################################################################

CFSSL_SERVE_ARGS="${CFSSL_SERVE_ARGS:-} -ca=/etc/cfssl/lower-ca-crt.pem"
CFSSL_SERVE_ARGS="${CFSSL_SERVE_ARGS:-} -ca-key=/etc/cfssl/lower-ca-key.pem"
CFSSL_SERVE_ARGS="${CFSSL_SERVE_ARGS:-} -responder=lower-ocsp-crt.pem"
CFSSL_SERVE_ARGS="${CFSSL_SERVE_ARGS:-} -responder-key=lower-ocsp-key.pem"
CFSSL_SERVE_ARGS="${CFSSL_SERVE_ARGS:-} -config=/etc/cfssl/config.json"
CFSSL_SERVE_ARGS="${CFSSL_SERVE_ARGS:-} -db-config=/etc/cfssl/db-config.json"
CFSSL_SERVE_ARGS="${CFSSL_SERVE_ARGS:-} -address=${CFSSL_SERVE_LISTEN_ADDR:-"0.0.0.0"}"
CFSSL_SERVE_ARGS="${CFSSL_SERVE_ARGS:-} -port=${CFSSL_SERVE_LISTEN_PORT:-"8888"}"
CFSSL_SERVE_ARGS="${CFSSL_SERVE_ARGS:-} -min-tls-version=${CFSSL_SERVE_MIN_TLS_VERSION:-"1.2"}"
CFSSL_SERVE_ARGS="${CFSSL_SERVE_ARGS:-} -loglevel=${CFSSL_SERVE_LOG_LOVEL:-"1"}"

mkdir -p /etc/sv/cfssl_serve
cat > /etc/sv/cfssl_serve/run <<- __EOF__
#!/bin/sh
set -e
exec 2>&1
exec /usr/local/bin/cfssl serve ${CFSSL_SERVE_ARGS}
__EOF__
chmod 0755 /etc/sv/cfssl_serve/run
ln -s /etc/sv/cfssl_serve /etc/service/cfssl_serve

CFSSL_OCSPSERVE_ARGS="${CFSSL_OCSPSERVE_ARGS:-} -db-config=/etc/cfssl/db-config.json"
CFSSL_OCSPSERVE_ARGS="${CFSSL_OCSPSERVE_ARGS:-} -address=${CFSSL_OCSPSERVE_LISTEN_ADDR:-"0.0.0.0"}"
CFSSL_OCSPSERVE_ARGS="${CFSSL_OCSPSERVE_ARGS:-} -port=${CFSSL_OCSPSERVE_LISTEN_PORT:-"8889"}"
CFSSL_OCSPSERVE_ARGS="${CFSSL_OCSPSERVE_ARGS:-} -loglevel=${CFSSL_OCSPSERVE_LOG_LOVEL:-"1"}"

mkdir -p /etc/sv/cfssl_ocspserve
cat > /etc/sv/cfssl_ocspserve/run <<- __EOF__
#!/bin/sh
set -e
exec 2>&1
exec /usr/local/bin/cfssl ocspserve ${CFSSL_OCSPSERVE_ARGS}
__EOF__
chmod 0755 /etc/sv/cfssl_ocspserve/run
ln -s /etc/sv/cfssl_ocspserve /etc/service/cfssl_ocspserve

################################################################################
# Running
################################################################################

if [ "$1" = "cfssl" ] && [ "$2" = "serve" ]; then
	exec runsvdir /etc/service
else
	exec "$@"
fi
