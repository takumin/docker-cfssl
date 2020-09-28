#
# Build Container
#

FROM golang:${GOLANG_BRANCH:-alpine} as build

RUN apk --no-cache --update add ca-certificates gcc musl-dev upx

ENV DOCKERIZE_VERSION v0.6.1
RUN wget -q https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz
RUN tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz
RUN chown root:root /usr/local/bin/dockerize
RUN rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz

ARG CFSSL_VERSION
ENV GOOS="linux"
ENV GOARCH="amd64"
ENV CGO_ENABLED="1"
ENV GOPROXY="off"
ENV GOFLAGS="-mod=vendor"
ENV GOBIN="/usr/local/bin"
ENV LDFLAGS="-s -w -extldflags \"-static\""

WORKDIR /go/src/github.com/cloudflare/cfssl
COPY cfssl .
RUN go build -o /go/bin/rice ./vendor/github.com/GeertJohan/go.rice/rice
RUN rice embed-go -i=./cli/serve
RUN go install -ldflags "-X github.com/cloudflare/cfssl/cli/version.version=${CFSSL_VERSION} ${LDFLAGS}" github.com/cloudflare/cfssl/cmd/...

RUN mkdir /usr/local/share/cfssl
RUN cp -r certdb/pg/migrations /usr/local/share/cfssl/postgres
RUN cp -r certdb/mysql/migrations /usr/local/share/cfssl/mysql
RUN cp -r certdb/sqlite/migrations /usr/local/share/cfssl/sqlite

WORKDIR /go/src/github.com/pressly/goose
COPY goose .
RUN go install -tags='no_clickhouse no_mssql no_redshift' -ldflags "${LDFLAGS}" github.com/pressly/goose/cmd/goose

RUN upx -1 /usr/local/bin/*

COPY injection/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

#
# Service Container
#

FROM alpine:${ALPINE_BRANCH:-latest} as service

COPY --from=build /usr/local/bin /usr/local/bin
COPY --from=build /usr/local/share/cfssl /usr/local/share/cfssl

RUN apk --no-cache --update add tzdata dumb-init runit ca-certificates

ENTRYPOINT ["dumb-init", "--", "docker-entrypoint.sh"]
CMD ["cfssl"]
