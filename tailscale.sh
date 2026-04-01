#!/bin/bash
# Copyright (c) 2024 Fluent Networks Pty Ltd & AUTHORS All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -m

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# Prepare run dirs
if [ ! -d "/var/run/sshd" ]; then
  mkdir -p /var/run/sshd
fi

# Set root password
echo "root:${PASSWORD}" | chpasswd

# Install routes
IFS=',' read -ra SUBNETS <<< "${ADVERTISE_ROUTES}"
for s in "${SUBNETS[@]}"; do
  ip route add "$s" via "${CONTAINER_GATEWAY}"
done

# Perform an update if set
if [[ ! -z "${UPDATE_TAILSCALE+x}" ]]; then
  /usr/local/bin/tailscale update --yes
fi

# Set login server for tailscale
if [[ -z "${LOGIN_SERVER}" ]]; then
	LOGIN_SERVER=https://controlplane.tailscale.com
fi

# Execute startup script if it exists
if [[ -n "${STARTUP_SCRIPT}" && -f "${STARTUP_SCRIPT}" ]]; then
       bash "${STARTUP_SCRIPT}" || exit $?
fi

# Start tailscaled and bring tailscale up
/usr/local/bin/tailscaled ${TAILSCALED_ARGS} &
until /usr/local/bin/tailscale up \
  --reset --authkey="${AUTH_KEY}" \
	--login-server "${LOGIN_SERVER}" \
	--advertise-routes="${ADVERTISE_ROUTES}" \
  ${TAILSCALE_ARGS}
do
    sleep 0.1
done
echo Tailscale started

# Check that a route exists for 100.64.0.0/10; if not, add
EXISTS=`ip route show 100.64.0.0/10 | wc -l`
if [ $EXISTS -eq 0 ]; then
  ip route add 100.64.0.0/10 dev tailscale0
fi

# Check that a route exists for fd7a:115c:a1e0::/48; if not, add
EXISTSV6=`ip -6 route show fd7a:115c:a1e0::/48 | wc -l`
if [ $EXISTSV6 -eq 0 ]; then
  ip -6 route add fd7a:115c:a1e0::/48 dev tailscale0
fi

# Execute running script if it exists
if [[ -n "${RUNNING_SCRIPT}" && -f "${RUNNING_SCRIPT}" ]]; then
       bash "${RUNNING_SCRIPT}" || exit $?
fi

# Start SSH
/usr/sbin/sshd -D

fg %1
