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
 $ ./scripts/revoke-client-certificate.sh
```

# Reference
- https://propellered.com/posts/cfssl_setting_up/
- https://propellered.com/posts/cfssl_setting_up_ocsp_api/
- https://propellered.com/posts/cfssl_revoking_certs_ocsp_reponder/
