#!/bin/bash

set -m

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# Prepare run dir
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

# Check if this is first-time container startup
if [ ! -f "/var/run/tailscale.sh.pid" ]; then
	# Delete all the old devices with this hostname.
	IDS=$(curl -sSL "https://api.tailscale.com/api/v2/domain/${DOMAIN}/devices" -u "${API_KEY}:" | jq -r '.[][]  | select(.hostname == "'${HOSTNAME}'") | .id' || echo "")
	while IFS= read -r id; do
		if [[ ! -z "$id" ]]; then
			echo "deleting tailscale device: $id";
			curl -sSL -XDELETE  -u "${API_KEY}:" "https://api.tailscale.com/api/v2/device/$id";
		fi
	done <<EOL
$IDS
EOL
fi

echo $$ >/var/run/tailscale.sh.pid

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
