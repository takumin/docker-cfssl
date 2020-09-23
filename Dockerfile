#
# Build Container
#

FROM golang:${GOLANG_BRANCH:-alpine} as build

RUN apk --no-cache --update add ca-certificates gcc musl-dev upx

ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz
RUN tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz
RUN rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz

WORKDIR /go/src/github.com/cloudflare/cfssl
COPY cfssl .
ARG CFSSL_VERSION
ENV GOOS="linux"
ENV GOARCH="amd64"
ENV CGO_ENABLED="1"
ENV GOPROXY="off"
ENV GOFLAGS="-mod=vendor"
ENV GOBIN="/usr/local/bin"
ENV LDFLAGS="-X github.com/cloudflare/cfssl/cli/version.version=${CFSSL_VERSION} -s -w -extldflags -static"
RUN go build -o /go/bin/rice ./vendor/github.com/GeertJohan/go.rice/rice
RUN rice embed-go -i=./cli/serve
RUN go install -ldflags "${LDFLAGS}" github.com/cloudflare/cfssl/cmd/...
RUN upx -1 /usr/local/bin/*

COPY injection/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

#
# Service Container
#

FROM alpine:${ALPINE_BRANCH:-latest} as service

COPY --from=build /usr/local/bin /usr/local/bin

RUN apk --no-cache --update add tzdata dumb-init runit ca-certificates

ENTRYPOINT ["dumb-init", "--", "docker-entrypoint.sh"]
CMD ["cfssl"]
