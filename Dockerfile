# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM golang:1.19.2-alpine as builder
RUN apk add --no-cache ca-certificates git
RUN apk add build-base
WORKDIR /src

ENV GOPRIVATE=github.com/retail-store-saas

COPY go.mod go.sum ./
# Setup go private modules
RUN --mount=type=secret,id=gh_token,dst=/run/secrets/gh_token,required=true \
    git config --global url."https://$(cat /run/secrets/gh_token):x-oauth-basic@github.com/retail-store-saas".insteadOf "https://github.com/retail-store-saas" && \
    go mod download

COPY . .
# Skaffold passes in debug-oriented compiler flags
ARG SKAFFOLD_GO_GCFLAGS
RUN --mount=type=cache,target=/root/.cache/go-build \
    go build -gcflags="${SKAFFOLD_GO_GCFLAGS}" -o /go/bin/frontend .

FROM alpine as release
LABEL org.opencontainers.image.source=https://github.com/retail-store-saas/frontend
LABEL io.snyk.containers.image.dockerfile=Dockerfile

RUN apk add --no-cache ca-certificates \
    busybox-extras net-tools bind-tools
WORKDIR /src
COPY --from=builder /go/bin/frontend /src/server
COPY ./templates ./templates
COPY ./static ./static

# Definition of this variable is used by 'skaffold debug' to identify a golang binary.
# Default behavior - a failure prints a stack trace for the current goroutine.
# See https://golang.org/pkg/runtime/
ENV GOTRACEBACK=single

EXPOSE 8080
ENTRYPOINT ["/src/server"]
