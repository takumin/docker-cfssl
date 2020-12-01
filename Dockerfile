#
# Build Container
#

FROM golang:${GOLANG_BRANCH:-alpine} as build

RUN apk --no-cache --update add ca-certificates git gcc musl-dev upx

ENV DOCKERIZE_VERSION v0.6.1
RUN wget -q https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz
RUN tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz
RUN chown root:root /usr/local/bin/dockerize
RUN rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz

ENV GOOS="linux"
ENV GOARCH="amd64"
ENV GOBIN="/usr/local/bin"
ENV LDFLAGS="-s -w -extldflags \"-static\""

WORKDIR /go/src/bitbucket.org/liamstask/goose
COPY goose .
RUN go mod init
RUN go mod tidy
RUN go mod verify
RUN go mod download
RUN go install -ldflags "${LDFLAGS}" bitbucket.org/liamstask/goose/cmd/goose

ARG CFSSL_VERSION
ENV GOPROXY="off"
ENV GOFLAGS="-mod=vendor"

WORKDIR /go/src/github.com/cloudflare/cfssl
COPY cfssl .
RUN go build -o /go/bin/rice ./vendor/github.com/GeertJohan/go.rice/rice
RUN rice embed-go -i=./cli/serve
RUN go install -ldflags "-X github.com/cloudflare/cfssl/cli/version.version=${CFSSL_VERSION} ${LDFLAGS}" github.com/cloudflare/cfssl/cmd/...

RUN mkdir /usr/local/share/cfssl
RUN cp -r certdb/pg /usr/local/share/cfssl/postgres
RUN cp -r certdb/mysql /usr/local/share/cfssl/mysql
RUN cp -r certdb/sqlite /usr/local/share/cfssl/sqlite3

RUN upx -1 /usr/local/bin/*

COPY injection/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

#
# Service Container
#

FROM alpine:${ALPINE_BRANCH:-latest} as service

RUN apk --no-cache --update add tzdata dumb-init runit ca-certificates

COPY --from=build /usr/local/bin /usr/local/bin
COPY --from=build /usr/local/share/cfssl /usr/local/share/cfssl

ENTRYPOINT ["dumb-init", "--", "docker-entrypoint.sh"]
CMD ["cfssl"]
