#!/bin/sh
# vim: set noet :

set -eu

##############################################################################
# Initialization
##############################################################################

if [ ! -d "/etc/cfssl" ]; then
	mkdir -p "/etc/cfssl"
fi

if [ ! -d "/var/lib/cfssl" ]; then
	mkdir -p "/var/lib/cfssl"
fi

##############################################################################
# Docker Secrets
##############################################################################

if [ -r "/run/secrets/cfssl_config_json" ]; then
	CFSSL_CONFIG_JSON="$(cat /run/secrets/cfssl_config_json)"
fi

if [ -r "/run/secrets/cfssl_root_ca_csr_json" ]; then
	CFSSL_ROOT_CA_CSR_JSON="$(cat /run/secrets/cfssl_root_ca_csr_json)"
fi

if [ -r "/run/secrets/cfssl_lower_ca_csr_json" ]; then
	CFSSL_LOWER_CA_CSR_JSON="$(cat /run/secrets/cfssl_lower_ca_csr_json)"
fi

if [ -r "/run/secrets/cfssl_ocsp_root_csr_json" ]; then
	CFSSL_OCSP_ROOT_CSR_JSON="$(cat /run/secrets/cfssl_ocsp_root_csr_json)"
fi

if [ -r "/run/secrets/cfssl_ocsp_lower_csr_json" ]; then
	CFSSL_OCSP_LOWER_CSR_JSON="$(cat /run/secrets/cfssl_ocsp_lower_csr_json)"
fi

if [ -r "/run/secrets/cfssl_root_ca_crt_pem" ]; then
	CFSSL_ROOT_CA_CRT_PEM="$(cat /run/secrets/cfssl_root_ca_crt_pem)"
fi

if [ -r "/run/secrets/cfssl_root_ca_key_pem" ]; then
	CFSSL_ROOT_CA_KEY_PEM="$(cat /run/secrets/cfssl_root_ca_key_pem)"
fi

if [ -r "/run/secrets/cfssl_lower_ca_crt_pem" ]; then
	CFSSL_LOWER_CA_CRT_PEM="$(cat /run/secrets/cfssl_lower_ca_crt_pem)"
fi

if [ -r "/run/secrets/cfssl_lower_ca_key_pem" ]; then
	CFSSL_LOWER_CA_KEY_PEM="$(cat /run/secrets/cfssl_lower_ca_key_pem)"
fi

if [ -r "/run/secrets/cfssl_ocsp_root_crt_pem" ]; then
	CFSSL_OCSP_ROOT_CRT_PEM="$(cat /run/secrets/cfssl_ocsp_root_crt_pem)"
fi

if [ -r "/run/secrets/cfssl_ocsp_root_key_pem" ]; then
	CFSSL_OCSP_ROOT_KEY_PEM="$(cat /run/secrets/cfssl_ocsp_root_key_pem)"
fi

if [ -r "/run/secrets/cfssl_ocsp_lower_crt_pem" ]; then
	CFSSL_OCSP_LOWER_CRT_PEM="$(cat /run/secrets/cfssl_ocsp_lower_crt_pem)"
fi

if [ -r "/run/secrets/cfssl_ocsp_lower_key_pem" ]; then
	CFSSL_OCSP_LOWER_KEY_PEM="$(cat /run/secrets/cfssl_ocsp_lower_key_pem)"
fi

##############################################################################
# Databases
##############################################################################

if [ -z "${CFSSL_CERTDB_TYPE:-}" ]; then
	CFSSL_CERTDB_TYPE="sqlite3"
fi

case "${CFSSL_CERTDB_TYPE}" in
	"sqlite3")
		CFSSL_CERTDB_SRC="/var/lib/cfssl/certstore.db"
		;;
	"postgres")
		CFSSL_CERTDB_SRC="${CFSSL_CERTDB_TYPE}://${CFSSL_CERTDB_USER}:${CFSSL_CERTDB_PASS}@${CFSSL_CERTDB_HOST}:${CFSSL_CERTDB_PORT}/${CFSSL_CERTDB_NAME}?sslmode=disable"
		dockerize -timeout "${CFSSL_CERTDB_WAIT:-"30s"}" -wait "tcp://${CFSSL_CERTDB_HOST}:${CFSSL_CERTDB_PORT}"
		;;
	"mysql")
		CFSSL_CERTDB_SRC="${CFSSL_CERTDB_USER}:${CFSSL_CERTDB_PASS}@tcp(${CFSSL_CERTDB_HOST}:${CFSSL_CERTDB_PORT})/${CFSSL_CERTDB_NAME}?parseTime=true"
		dockerize -timeout "${CFSSL_CERTDB_WAIT:-"30s"}" -wait "tcp://${CFSSL_CERTDB_HOST}:${CFSSL_CERTDB_PORT}"
		;;
	*)
		echo "Invalid Environment Variable: CFSSL_CERTDB_TYPE: ${CFSSL_CERTDB_TYPE}"
		exit 1
		;;
esac

cat > "/etc/cfssl/db-config.json" <<- __EOF__
{
	"driver": "${CFSSL_CERTDB_TYPE}",
	"data_source": "${CFSSL_CERTDB_SRC}"
}
__EOF__

{
	echo "service:"
	echo "  driver: ${CFSSL_CERTDB_TYPE}"
	echo "  open: ${CFSSL_CERTDB_SRC}"
} > "/usr/local/share/cfssl/${CFSSL_CERTDB_TYPE}/dbconf.yml"

goose -env "service" -path "/usr/local/share/cfssl/${CFSSL_CERTDB_TYPE}" up

##############################################################################
# Configuration
##############################################################################

if [ -n "${CFSSL_CONFIG_JSON:-}" ]; then
	echo 'Output from env:CFSSL_CONFIG_JSON to file:/etc/cfssl/config.json'

	echo "${CFSSL_CONFIG_JSON}" > "/etc/cfssl/config.json"
else
	if [ ! -f "/etc/cfssl/config.json" ]; then
		echo 'Generate file:/etc/cfssl/config.json'

		cat > "/etc/cfssl/config.json" <<- __EOF__
		{
			"signing": {
				"default": {
					"expiry": "720h"
				},
				"profiles": {
					"root": {
						"expiry": "87600h",
						"usages": [
							"cert sign",
							"crl sign"
						],
						"ca_constraint": {
							"is_ca": true,
							"max_path_len": 1,
							"max_path_len_zero": false
						}
					},
					"lower": {
						"expiry": "43800h",
						"usages": [
							"cert sign",
							"crl sign"
						],
						"ca_constraint": {
							"is_ca": true,
							"max_path_len": 0,
							"max_path_len_zero": true
						}
					},
					"ocsp": {
						"expiry": "8760h",
						"usages": [
							"digital signature",
							"ocsp signing"
						]
					},
					"server": {
						"expiry": "720h",
						"usages": [
							"signing",
							"key encipherment",
							"server auth"
						]
					},
					"client": {
						"expiry": "720h",
						"usages": [
							"signing",
							"key encipherment",
							"client auth"
						]
					}
				}
			}
		}
		__EOF__
	fi
fi

if [ -n "${CFSSL_ROOT_CA_CSR_JSON:-}" ]; then
	echo 'Output from env:CFSSL_ROOT_CA_CSR_JSON to file:/etc/cfssl/root-ca-csr.json'

	echo "${CFSSL_ROOT_CA_CSR_JSON}" > "/etc/cfssl/root-ca-csr.json"
else
	if [ ! -f "/etc/cfssl/root-ca-csr.json" ]; then
		echo 'Generate file:/etc/cfssl/root-ca-csr.json'

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
	echo 'Output from env:CFSSL_LOWER_CA_CSR_JSON to file:/etc/cfssl/lower-ca-csr.json'

	echo "${CFSSL_LOWER_CA_CSR_JSON}" > "/etc/cfssl/lower-ca-csr.json"
else
	if [ ! -f "/etc/cfssl/lower-ca-csr.json" ]; then
		echo 'Generate file:/etc/cfssl/lower-ca-csr.json'

		cat > "/etc/cfssl/lower-ca-csr.json" <<- __EOF__
		{
			"CN": "Lower CA",
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

if [ -n "${CFSSL_OCSP_ROOT_CSR_JSON:-}" ]; then
	echo 'Output from env:CFSSL_OCSP_ROOT_CSR_JSON to file:/etc/cfssl/ocsp-root-csr.json'

	echo "${CFSSL_OCSP_ROOT_CSR_JSON}" > "/etc/cfssl/ocsp-root-csr.json"
else
	if [ ! -f "/etc/cfssl/ocsp-root-csr.json" ]; then
		echo 'Generate file:/etc/cfssl/ocsp-root-csr.json'

		cat > "/etc/cfssl/ocsp-root-csr.json" <<- __EOF__
		{
			"CN": "Root CA OCSP Responder",
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

if [ -n "${CFSSL_OCSP_LOWER_CSR_JSON:-}" ]; then
	echo 'Output from env:CFSSL_OCSP_LOWER_CSR_JSON to file:/etc/cfssl/ocsp-lower-csr.json'

	echo "${CFSSL_OCSP_LOWER_CSR_JSON}" > "/etc/cfssl/ocsp-lower-csr.json"
else
	if [ ! -f "/etc/cfssl/ocsp-lower-csr.json" ]; then
		echo 'Generate file:/etc/cfssl/ocsp-lower-csr.json'

		cat > "/etc/cfssl/ocsp-lower-csr.json" <<- __EOF__
		{
			"CN": "Lower CA OCSP Responder",
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
# Root CA Certificate
##############################################################################

if [ -n "${CFSSL_ROOT_CA_KEY_PEM:-}" ] && [ -n "${CFSSL_ROOT_CA_CRT_PEM:-}" ]; then
	echo 'Output from env:CFSSL_ROOT_CA_KEY_PEM to file:/etc/cfssl/root-ca-key.pem'
	echo 'Output from env:CFSSL_ROOT_CA_CRT_PEM to file:/etc/cfssl/root-ca-crt.pem'

	echo "${CFSSL_ROOT_CA_KEY_PEM}" > "/etc/cfssl/root-ca-key.pem"
	echo "${CFSSL_ROOT_CA_CRT_PEM}" > "/etc/cfssl/root-ca-crt.pem"
else
	echo 'Generate file:/etc/cfssl/root-ca-key.pem'
	echo 'Generate file:/etc/cfssl/root-ca-csr.pem'
	echo 'Generate file:/etc/cfssl/root-ca-crt.pem'

	cfssl gencert \
		-initca \
		-config="/etc/cfssl/config.json" \
		-profile="root" \
		"/etc/cfssl/root-ca-csr.json" \
		| cfssljson -bare -stdout > "/tmp/cfssl"

	awk '/^-----BEGIN CERTIFICATE-----$/,/^-----END CERTIFICATE-----$/' "/tmp/cfssl" > "/etc/cfssl/root-ca-crt.pem"
	awk '/^-----BEGIN .* PRIVATE KEY-----$/,/^-----END .* PRIVATE KEY-----$/' "/tmp/cfssl" > "/etc/cfssl/root-ca-key.pem"
	awk '/^-----BEGIN CERTIFICATE REQUEST-----$/,/^-----END CERTIFICATE REQUEST-----$/' "/tmp/cfssl" > "/etc/cfssl/root-ca-csr.pem"

	rm "/tmp/cfssl"

	echo 'Re-Signed file:/etc/cfssl/root-ca-crt.pem'
	cfssl sign \
		-ca="/etc/cfssl/root-ca-crt.pem" \
		-ca-key="/etc/cfssl/root-ca-key.pem" \
		-config="/etc/cfssl/config.json" \
		-profile="root" \
		"/etc/cfssl/root-ca-csr.pem" \
		| cfssljson -bare -stdout \
		| awk '/^-----BEGIN CERTIFICATE-----$/,/^-----END CERTIFICATE-----$/' \
		> "/tmp/cfssl"
	mv "/tmp/cfssl" "/etc/cfssl/root-ca-crt.pem"
fi

##############################################################################
# Lower CA Certificate
##############################################################################

if [ -n "${CFSSL_LOWER_CA_KEY_PEM:-}" ] && [ -n "${CFSSL_LOWER_CA_CRT_PEM:-}" ]; then
	echo 'Output from env:CFSSL_LOWER_CA_KEY_PEM to file:/etc/cfssl/lower-ca-key.pem'
	echo 'Output from env:CFSSL_LOWER_CA_CRT_PEM to file:/etc/cfssl/lower-ca-crt.pem'

	echo "${CFSSL_LOWER_CA_KEY_PEM}" > "/etc/cfssl/lower-ca-key.pem"
	echo "${CFSSL_LOWER_CA_CRT_PEM}" > "/etc/cfssl/lower-ca-crt.pem"
else
	echo 'Generate file:/etc/cfssl/lower-ca-key.pem'
	cfssl genkey \
		"/etc/cfssl/lower-ca-csr.json" \
		| cfssljson -bare -stdout \
		| awk '/^-----BEGIN .* PRIVATE KEY-----$/,/^-----END .* PRIVATE KEY-----$/' \
		> "/etc/cfssl/lower-ca-key.pem"

	echo 'Generate file:/etc/cfssl/lower-ca-csr.pem'
	cfssl gencsr \
		-key="/etc/cfssl/lower-ca-key.pem" \
		"/etc/cfssl/lower-ca-csr.json" \
		| cfssljson -bare -stdout \
		| awk '/^-----BEGIN CERTIFICATE REQUEST-----$/,/^-----END CERTIFICATE REQUEST-----$/' \
		> "/etc/cfssl/lower-ca-csr.pem"

	echo 'Generate file:/etc/cfssl/lower-ca-crt.pem'
	cfssl sign \
		-ca="/etc/cfssl/root-ca-crt.pem" \
		-ca-key="/etc/cfssl/root-ca-key.pem" \
		-config="/etc/cfssl/config.json" \
		-profile="lower" \
		"/etc/cfssl/lower-ca-csr.pem" \
		| cfssljson -bare -stdout \
		| awk '/^-----BEGIN CERTIFICATE-----$/,/^-----END CERTIFICATE-----$/' \
		> "/etc/cfssl/lower-ca-crt.pem"
fi

##############################################################################
# Root CA OCSP Responder Certificate
##############################################################################

if [ -n "${CFSSL_OCSP_ROOT_KEY_PEM:-}" ] && [ -n "${CFSSL_OCSP_ROOT_CRT_PEM:-}" ]; then
	echo 'Output from env:CFSSL_OCSP_ROOT_KEY_PEM to file:/etc/cfssl/ocsp-root-key.pem'
	echo 'Output from env:CFSSL_OCSP_ROOT_CRT_PEM to file:/etc/cfssl/ocsp-root-crt.pem'

	echo "${CFSSL_OCSP_ROOT_KEY_PEM}" > "/etc/cfssl/ocsp-root-key.pem"
	echo "${CFSSL_OCSP_ROOT_CRT_PEM}" > "/etc/cfssl/ocsp-root-crt.pem"
else
	echo 'Generate file:/etc/cfssl/ocsp-root-key.pem'
	cfssl genkey \
		"/etc/cfssl/ocsp-root-csr.json" \
		| cfssljson -bare -stdout \
		| awk '/^-----BEGIN .* PRIVATE KEY-----$/,/^-----END .* PRIVATE KEY-----$/' \
		> "/etc/cfssl/ocsp-root-key.pem"

	echo 'Generate file:/etc/cfssl/ocsp-root-csr.pem'
	cfssl gencsr \
		-key="/etc/cfssl/ocsp-root-key.pem" \
		"/etc/cfssl/ocsp-root-csr.json" \
		| cfssljson -bare -stdout \
		| awk '/^-----BEGIN CERTIFICATE REQUEST-----$/,/^-----END CERTIFICATE REQUEST-----$/' \
		> "/etc/cfssl/ocsp-root-csr.pem"

	echo 'Generate file:/etc/cfssl/ocsp-root-crt.pem'
	cfssl sign \
		-ca="/etc/cfssl/root-ca-crt.pem" \
		-ca-key="/etc/cfssl/root-ca-key.pem" \
		-config="/etc/cfssl/config.json" \
		-profile="ocsp" \
		"/etc/cfssl/ocsp-root-csr.pem" \
		| cfssljson -bare -stdout \
		| awk '/^-----BEGIN CERTIFICATE-----$/,/^-----END CERTIFICATE-----$/' \
		> "/etc/cfssl/ocsp-root-crt.pem"
fi

##############################################################################
# Lower CA OCSP Responder Certificate
##############################################################################

if [ -n "${CFSSL_OCSP_LOWER_KEY_PEM:-}" ] && [ -n "${CFSSL_OCSP_LOWER_CRT_PEM:-}" ]; then
	echo 'Output from env:CFSSL_OCSP_LOWER_KEY_PEM to file:/etc/cfssl/ocsp-lower-key.pem'
	echo 'Output from env:CFSSL_OCSP_LOWER_CRT_PEM to file:/etc/cfssl/ocsp-lower-crt.pem'

	echo "${CFSSL_OCSP_LOWER_KEY_PEM}" > "/etc/cfssl/ocsp-lower-key.pem"
	echo "${CFSSL_OCSP_LOWER_CRT_PEM}" > "/etc/cfssl/ocsp-lower-crt.pem"
else
	echo 'Generate file:/etc/cfssl/ocsp-lower-key.pem'
	cfssl genkey \
		"/etc/cfssl/ocsp-lower-csr.json" \
		| cfssljson -bare -stdout \
		| awk '/^-----BEGIN .* PRIVATE KEY-----$/,/^-----END .* PRIVATE KEY-----$/' \
		> "/etc/cfssl/ocsp-lower-key.pem"

	echo 'Generate file:/etc/cfssl/ocsp-lower-csr.pem'
	cfssl gencsr \
		-key="/etc/cfssl/ocsp-lower-key.pem" \
		"/etc/cfssl/ocsp-lower-csr.json" \
		| cfssljson -bare -stdout \
		| awk '/^-----BEGIN CERTIFICATE REQUEST-----$/,/^-----END CERTIFICATE REQUEST-----$/' \
		> "/etc/cfssl/ocsp-lower-csr.pem"

	echo 'Generate file:/etc/cfssl/ocsp-lower-crt.pem'
	cfssl sign \
		-ca="/etc/cfssl/lower-ca-crt.pem" \
		-ca-key="/etc/cfssl/lower-ca-key.pem" \
		-config="/etc/cfssl/config.json" \
		-profile="ocsp" \
		"/etc/cfssl/ocsp-lower-csr.pem" \
		| cfssljson -bare -stdout \
		| awk '/^-----BEGIN CERTIFICATE-----$/,/^-----END CERTIFICATE-----$/' \
		> "/etc/cfssl/ocsp-lower-crt.pem"
fi

##############################################################################
# OCSP Responder Initialize
##############################################################################

echo 'Generate file:/etc/cfssl/ocsp-responses.txt'
cfssl ocspsign \
	-ca="/etc/cfssl/root-ca-crt.pem" \
	-responder="/etc/cfssl/ocsp-root-crt.pem" \
	-responder-key="/etc/cfssl/ocsp-root-key.pem" \
	-cert="/etc/cfssl/lower-ca-crt.pem" \
	| cfssljson -bare -stdout \
	> "/etc/cfssl/ocsp-root-responses.txt"
cp "/etc/cfssl/ocsp-root-responses.txt" "/etc/cfssl/ocsp-responses.txt"

##############################################################################
# OCSP Responder Refresh
##############################################################################

cat > "/usr/local/bin/cfssl-ocsp-refresh" << __EOF__
#!/bin/sh

set -eu

cfssl ocsprefresh \
	-db-config="/etc/cfssl/db-config.json" \
	-ca="/etc/cfssl/lower-ca-crt.pem" \
	-responder="/etc/cfssl/ocsp-lower-crt.pem" \
	-responder-key="/etc/cfssl/ocsp-lower-key.pem"

cfssl ocspdump \
	-db-config="/etc/cfssl/db-config.json" \
	>> "/etc/cfssl/ocsp-lower-responses.txt"

cat "/etc/cfssl/ocsp-root-responses.txt" \
	"/etc/cfssl/ocsp-lower-responses.txt" \
	> "/etc/cfssl/ocsp-responses.txt"

sv t cfssl_ocspserve
__EOF__
chmod +x "/usr/local/bin/cfssl-ocsp-refresh"

##############################################################################
# Service
##############################################################################

CFSSL_SERVE_ARGS="${CFSSL_SERVE_ARGS:-} -ca=/etc/cfssl/lower-ca-crt.pem"
CFSSL_SERVE_ARGS="${CFSSL_SERVE_ARGS:-} -ca-key=/etc/cfssl/lower-ca-key.pem"
CFSSL_SERVE_ARGS="${CFSSL_SERVE_ARGS:-} -responder=/etc/cfssl/ocsp-lower-crt.pem"
CFSSL_SERVE_ARGS="${CFSSL_SERVE_ARGS:-} -responder-key=/etc/cfssl/ocsp-lower-key.pem"
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
CFSSL_OCSPSERVE_ARGS="${CFSSL_OCSPSERVE_ARGS:-} -responses=/etc/cfssl/ocsp-responses.txt"
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
