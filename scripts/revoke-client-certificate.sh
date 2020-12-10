#!/bin/bash

set -eux

cd testdata

find . -type f -not -name '.gitkeep' | xargs rm -f

docker cp cfssl:/etc/cfssl/root-ca-crt.pem .
docker cp cfssl:/etc/cfssl/lower-ca-crt.pem .
cat root-ca-crt.pem lower-ca-crt.pem > chain.pem

openssl ecparam -name prime256v1 -out prime256v1.pem
openssl req -new -newkey ec:prime256v1.pem -nodes -keyout client.key -out client.csr -subj '/CN=client/'

cfssl sign -remote "localhost:8888" -profile "client" client.csr | cfssljson -bare client

openssl x509 -in client.pem -noout -text
openssl verify -CAfile chain.pem client.pem

SERIAL_NUMBER="$(cfssl certinfo -cert client.pem | jq -r '.serial_number')"
AUTHORITY_KEY_ID="$(cfssl certinfo -cert client.pem | jq -r '.authority_key_id' | sed -E 's@:@@g; s@(.*)@\L\1@;')"

curl -d "{\"serial\": \"${SERIAL_NUMBER}\",\"authority_key_id\":\"${AUTHORITY_KEY_ID}\",\"reason\":\"superseded\"}" localhost:8888/api/v1/cfssl/revoke

docker exec -i -t cfssl cfssl-ocsp-refresh

sleep 1

openssl ocsp -issuer lower-ca-crt.pem -no_nonce -cert client.pem -CAfile chain.pem -url http://127.0.0.1:8889
