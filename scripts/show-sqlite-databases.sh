#!/bin/bash

docker exec -i -t cfssl sh -c 'apk list --no-network --no-cache -I | grep -sq "^sqlite" || apk add sqlite'
docker exec -i -t cfssl sqlite3 /var/lib/cfssl/certstore.db 'select * from certificates;'
docker exec -i -t cfssl sqlite3 /var/lib/cfssl/certstore.db 'select * from ocsp_responses;'
