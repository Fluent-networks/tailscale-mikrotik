# Tailscale for Mikrotik Container

This project provides the build and configuration information to run [Tailscale](https://tailscale.com) in [Mikrotik Container](https://help.mikrotik.com/docs/display/ROS/Container). Container is MikroTik's own implementation of Docker(TM), allowing users to run containerized environments within RouterOS.

This project is recommended for research and testing purposes only. Running Container currently requires installing the development branch of RouterOS and is unsupported for production use. Testing indicates there are also significant performance impacts: running a unidirectional IPerf UDP test of 30 Mbps via the container on a Mikrotik hAP ac3 consumes ~75% of the router's CPU.

## Instructions

The instructions below assume a use case for tailscale-enabled hosts accessing a router connected LAN subnet. The container runs as a [tailscale subnet router](https://tailscale.com/kb/1019/subnets/) on a Mikrotik hAP ac3. There are two subnets configured:
* 192.168.88.0/24: the default bridge with physical LAN interface ports, routed to the tailscale network
* 192.168.99.0/24: the docker bridge with a virtual ethernet (veth) interface port for the container

A WAN interface is configured as per default configuration on **ether1** for connectivity to the Tailscale Network. Note storage of the docker image on the router uses a USB drive mounted as **disk1** due to the limited storage (128MB) available on the router.

### Build the Docker Image

The build script uses [Docker Buildx](https://docs.docker.com/buildx/working-with-buildx/).

1. In `build.sh` set the PLATFORM shell script variable as required for the target router CPU - see https://mikrotik.com/products/matrix
2. In `Dockerfile` set the following arguments.

| Argument           | Description                     |
| ------------------ | ------------------------------- |
| TAILSCALE_USER     | Tailscale user name             |
| TAILSCALE_PASSWORD | Password for the tailscale user |

3. Run `./build.sh` to build the image. The build process will generate a container image file **`tailscale.tar`**

### Configure the Router

The router must be be running  RouterOS v7.1rc3 or later with the container package loaded; this section follows the Mikrotik Container documentation with additional steps to route the LAN subnet via the tailscale container.

1. Upload the `tailscale.tar` file to your router. Below we will assume the image is located at `disk1/tailscale.tar`

2. Create a veth interface for the container.

```
/interface/veth add name=veth1 address=192.168.99.2/24 gateway=192.168.99.1
```

3. Create a bridge for containers and add veth to it

```
/interface/bridge add name=docker
/ip/address add address=192.168.99.1/24 interface=docker
/interface/bridge/port add bridge=docker interface=veth1
```

4. Create environment variables as per the list below.

| Variable          | Description                                   | Comment                                      |
| ----------------- | --------------------------------------------- | -------------------------------------------- |
| AUTH_KEY          | Tailscale reusable key                        | Generate the key from the tailscale console. |
| ADVERTISE_ROUTES  | Comma-separated list of routes to advertise   |                                              |
| CONTAINER_GATEWAY | The Container bridge IP address on the router |                                              |

```
/container/envs
add list="tailscale" name="AUTH_KEY" value="tskey-xxxxxxxxxxxxxxxxxxxxxxxx"
add list="tailscale" name="ADVERTISE_ROUTES" value="192.168.88.0/24"
add list="tailscale" name="CONTAINER_GATEWAY" value="192.168.99.1"
```

5. Create a container from the tailscale.tar image

```
/container add file=disk1/tailscale.tar interface=veth1 envlist=tailscale root-dir=disk1/containers/tailscale hostname=mikrotik
```

If you want to see the container output in the router log add `logging=yes` 

6. Configure container routing - create a secondary LAN IP address and apply inbound and outbound NAT rules. Here we apply rules for ICMP, UDP and TCP.

```
/ip/address add address=192.168.88.2/32 interface=bridge
/ip/firewall/nat
add chain=srcnat action=src-nat to-addresses=192.168.88.2 src-address=192.168.99.2 out-interface=bridge
add chain=dstnat action=dst-nat to-addresses=192.168.99.2 dst-address=192.168.88.2
add chain=srcnat action=src-nat to-addresses=192.168.88.2 protocol=udp src-address=192.168.99.2 out-interface=bridge
add chain=dstnat action=dst-nat to-addresses=192.168.99.2 protocol=udp dst-address=192.168.88.2
add chain=srcnat action=src-nat to-addresses=192.168.88.2 protocol=icmp src-address=192.168.99.2 out-interface=bridge
add chain=dstnat action=dst-nat to-addresses=192.168.99.2 protocol=icmp dst-address=192.168.88.2
```

### Start the Container

Ensure the container has been extracted and added by verifying `status=stopped` using `/container/print` 

```
/container/start 0
```

### Verify Connectivity

In the Tailscale console, verify the router is authenticated and enable the subnet routes. Your tailscale hosts should now be able to reach the router's LAN subnet. 

Note that the container exposes a SSH server for management purposes using the TAILSCALE_USER credentials, and can be accessed via the tailscale address or the LAN secondary IP address.

## Contributing

We welcome suggestions and feedback from people interested in integrating tailscale on the RouterOS platform. Please send a PR or create an issue if you're having any problems.



