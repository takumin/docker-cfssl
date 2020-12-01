# docker-cfssl
CFSSL for Docker Container Image

# docker-compose
Required package for [wait-for-it](https://packages.ubuntu.com/focal/wait-for-it) and [jq](https://packages.ubuntu.com/focal/jq)

## OpenSSL mTLS Test

terminal 1

```bash
 $ docker-compose down
 $ docker-compose up -d
 $ wait-for-it localhost:8080
 $ cd testdata
 $ docker cp cfssl:/etc/cfssl/root-ca-crt.pem .
 $ docker cp cfssl:/etc/cfssl/lower-ca-crt.pem .
 $ cat root-ca-crt.pem lower-ca-crt.pem > chain.pem
 $ cfssl print-defaults csr | cfssl gencert -remote localhost:8888 -profile server - | cfssljson -bare server
 $ cfssl print-defaults csr | cfssl gencert -remote localhost:8888 -profile client - | cfssljson -bare client
 $ openssl s_server -CAfile chain.pem -key server-key.pem -cert server.pem -accept 4433 -state
```

terminal 2

```bash
 $ openssl s_client -connect localhost:4433 -CAfile chain.pem -key client-key.pem -cert client.pem -state < /dev/null
```

## Revoke Client Certificate

```bash
 $ docker-compose down
 $ docker-compose up -d
 $ wait-for-it localhost:8080
 $ cd testdata
 $ docker cp cfssl:/etc/cfssl/root-ca-crt.pem .
 $ docker cp cfssl:/etc/cfssl/lower-ca-crt.pem .
 $ cat root-ca-crt.pem lower-ca-crt.pem > chain.pem
 $ openssl ecparam -name prime256v1 -out prime256v1.pem
 $ openssl req -new -newkey ec:prime256v1.pem -nodes -keyout client.key -out client.csr -subj '/CN=client/'
 $ cfssl sign -remote "localhost:8888" -profile "client" client.csr | cfssljson -bare client
 $ openssl x509 -in client.pem -noout -text
 $ openssl verify -CAfile chain.pem client.pem
 $ SERIAL_NUMBER="$(cfssl certinfo -cert client.pem | jq -r '.serial_number')"
 $ AUTHORITY_KEY_ID="$(cfssl certinfo -cert client.pem | jq -r '.authority_key_id' | sed -E 's@:@@g; s@(.*)@\L\1@;')"
 $ curl -d "{\"serial\": \"${SERIAL_NUMBER}\",\"authority_key_id\":\"${AUTHORITY_KEY_ID}\",\"reason\":\"superseded\"}" localhost:8888/api/v1/cfssl/revoke
 $ docker exec -i -t cfssl cfssl ocsprefresh -db-config /etc/cfssl/db-config.json -responder /etc/cfssl/ocsp-serve-crt.pem -responder-key /etc/cfssl/ocsp-serve-key.pem -ca /etc/cfssl/lower-ca-crt.pem
 $ openssl ocsp -issuer lower-ca-crt.pem -no_nonce -cert client.pem -CAfile chain.pem -url http://127.0.0.1:8889
```

# Reference
- https://propellered.com/posts/cfssl_setting_up/
- https://propellered.com/posts/cfssl_setting_up_ocsp_api/
- https://propellered.com/posts/cfssl_revoking_certs_ocsp_reponder/
