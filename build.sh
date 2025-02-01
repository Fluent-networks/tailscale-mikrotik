#!/usr/bin/env sh
# Copyright (c) 2024 Fluent Networks Pty Ltd & AUTHORS All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.
#
# Updates tailscale respository and runs `docker build` with flags configured for 
# docker distribution. 
# 
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
#
# Set PLATFORM as required for your router model. See:
# https://mikrotik.com/products/matrix
#
PLATFORM="linux/amd64"
TAILSCALE_VERSION=1.78.1
VERSION=0.1.35

set -eu

rm -f tailscale.tar

if [ ! -d ./tailscale/.git ]
then
    git -c advice.detachedHead=false clone https://github.com/tailscale/tailscale.git --branch v$TAILSCALE_VERSION
fi

TS_USE_TOOLCHAIN="Y"
cd tailscale && eval $(./build_dist.sh shellvars) && cd ..

docker buildx build \
  --no-cache \
  --build-arg TAILSCALE_VERSION=$TAILSCALE_VERSION \
  --build-arg VERSION_LONG=$VERSION_LONG \
  --build-arg VERSION_SHORT=$VERSION_SHORT \
  --build-arg VERSION_GIT_HASH=$VERSION_GIT_HASH \
  --platform $PLATFORM \
  --load -t ghcr.io/fluent-networks/tailscale-mikrotik:$VERSION .

docker save -o tailscale.tar ghcr.io/fluent-networks/tailscale-mikrotik:$VERSION
