# docker-cfssl
CFSSL for Docker Container Image

# docker-compose
```bash
 $ cfssl print-defaults config > ca-config.json
 $ cfssl print-defaults csr > ca-csr.json
 $ cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
 $ chmod 0644 ca-key.pem
 $ docker-compose up -d
```
