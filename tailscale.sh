#!/bin/bash

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

# Check if the machine exists
ID=$(curl -sSL "https://api.tailscale.com/api/v2/domain/${DOMAIN}/devices" -u "${API_KEY}:" | jq -r '.[][]  | select(.hostname == "'${HOSTNAME}'") | .id' || echo "")
if [[ ! -z "$ID" ]]; then
	# Check if this is a differing version. If so, remove the machine
	VERSION=$(tailscale version | head -n 1)
	CLIENT_VERSION=$(curl -sSL -XGET  -u "${API_KEY}:" "https://api.tailscale.com/api/v2/device/$ID" | jq -r '.clientVersion' || echo "")
	if [[ "$CLIENT_VERSION" != "$VERSION"* ]]; then
		# Delete the machine
		echo "Deleting tailscale machine: $ID";
		curl -sSL -XDELETE  -u "${API_KEY}:" "https://api.tailscale.com/api/v2/device/$ID";
	fi
fi

# Start tailscaled and bring tailscale up
/usr/local/bin/tailscaled &
until /usr/local/bin/tailscale up \
  --reset --authkey=${AUTH_KEY} \
	--advertise-routes="${ADVERTISE_ROUTES}" \
  ${TAILSCALE_ARGS}
do
    sleep 0.1
done
echo Tailscale started

# Start SSH
/usr/sbin/sshd -D

fg %1
