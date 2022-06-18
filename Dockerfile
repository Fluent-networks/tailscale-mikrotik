# Copyright (c) 2020 Tailscale Inc & AUTHORS All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

############################################################################
#
# WARNING: Tailscale is not yet officially supported in Docker,
# Kubernetes, etc.
#
# It might work, but we don't regularly test it, and it's not as polished as
# our currently supported platforms. This is provided for people who know
# how Tailscale works and what they're doing.
#
# Our tracking bug for officially support container use cases is:
#    https://github.com/tailscale/tailscale/issues/504
#
# Also, see the various bugs tagged "containers":
#    https://github.com/tailscale/tailscale/labels/containers
#
############################################################################

FROM golang:1.18-alpine AS build-env

WORKDIR /go/src/tailscale

COPY tailscale/go.mod tailscale/go.sum ./
RUN go mod download

COPY tailscale/. .

# see build.sh
ARG VERSION_LONG=""
ENV VERSION_LONG=$VERSION_LONG
ARG VERSION_SHORT=""
ENV VERSION_SHORT=$VERSION_SHORT
ARG VERSION_GIT_HASH=""
ENV VERSION_GIT_HASH=$VERSION_GIT_HASH
ARG TARGETARCH

RUN GOARCH=$TARGETARCH go install -ldflags="\
      -X tailscale.com/version.Long=$VERSION_LONG \
      -X tailscale.com/version.Short=$VERSION_SHORT \
      -X tailscale.com/version.GitCommit=$VERSION_GIT_HASH" \
      -v ./cmd/tailscale ./cmd/tailscaled

FROM ghcr.io/tailscale/alpine-base:3.14

# Set username and password
ARG TAILSCALE_USER="tailscale"
ARG TAILSCALE_PASSWORD="Pm36g58CzaLK"

RUN apk add --no-cache ca-certificates iptables iproute2 bash sudo openssh

RUN addgroup -S tailscale
RUN adduser --shell /bin/bash -S $TAILSCALE_USER -G tailscale \
      && echo "$TAILSCALE_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$TAILSCALE_USER \
      && chmod 0440 /etc/sudoers.d/$TAILSCALE_USER
RUN echo "tailscale:$TAILSCALE_PASSWORD" | chpasswd

RUN ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
RUN ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa

COPY --from=build-env /go/bin/* /usr/local/bin/

EXPOSE 22
ADD tailscale.sh /usr/local/bin
CMD ["/usr/local/bin/tailscale.sh"]

