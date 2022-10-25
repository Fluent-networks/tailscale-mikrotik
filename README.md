# Tailscale for Mikrotik Container

This project provides build and configuration information to run [Tailscale](https://tailscale.com) in [Mikrotik Container](https://help.mikrotik.com/docs/display/ROS/Container). Container is Mikrotik's own implementation of Docker(TM), allowing users to run containerized environments within RouterOS.

This project is only recommended for research and testing purposes. Testing indicates there are significant performance hurdles: running a unidirectional IPerf UDP test of 50 Mbps via the container on a Mikrotik hAP ac3 consumes ~75% of the router's CPU.

## Instructions

The instructions below assume a use case for tailscale-enabled hosts accessing a router connected LAN subnet. The container runs as a [tailscale subnet router](https://tailscale.com/kb/1019/subnets/) on a Mikrotik hAP ac3. There are two subnets configured:

* 192.168.88.0/24: the default bridge with physical LAN interface ports, routed to the tailscale network
* 172.17.0.0/16: the docker bridge with a virtual ethernet (veth) interface port for the container

A WAN interface is configured as per default configuration on **ether1** for connectivity to the Tailscale Network. Note storage of the docker image on the router uses a USB drive mounted as **disk1** due to the limited storage (128MB) available on the router.

### Build the Docker Image

Note this step is only required if you are uploading an image to your router. See Configuration Step 6.

The build script uses [Docker Buildx](https://docs.docker.com/buildx/working-with-buildx/).

1. In `build.sh` set the PLATFORM shell script variable as required for the target router CPU - see [https://mikrotik.com/products/matrix](https://mikrotik.com/products/matrix)

2. Run `./build.sh` to build the image. The build process will generate a container image archive file **`tailscale.tar`**

### Configure the Router

The router must be be running RouterOS v7.6 or later with the container package loaded; this section follows the Mikrotik Container documentation with additional steps to route the LAN subnet via the tailscale container.


1. Enable container mode, and reboot.

```
/system/device-mode/update container=yes
```

2. Create a veth interface for the container.

```
/interface/veth add name=veth1 address=172.17.0.2/16 gateway=172.17.0.1
```

3. Create a bridge for the container and add veth1 as a port.

```
/interface/bridge add name=dockers
/ip/address add address=172.17.0.1/16 interface=dockers
/interface/bridge/port add bridge=dockers interface=veth1
```

4. Enable routing from the LAN to the Tailscale Network 

```
/ip/route/add dst-address=100.64.0.0/10 gateway=172.17.0.2
```

5. Add environment variables as per the list below.

| Variable          | Description                                   | Comment                                      |
| ----------------- | --------------------------------------------- | -------------------------------------------- |
| PASSWORD          | System root user password                     |                                              |
| DOMAIN            | Tailscale domain                              |                                              |
| AUTH_KEY          | Tailscale reusable key                        | Generate from the tailscale console          |
| API_KEY           | Tailscale API key                             | See Upgrading section below                  |
| ADVERTISE_ROUTES  | Comma-separated list of routes to advertise   |                                              |
| CONTAINER_GATEWAY | The container bridge IP address on the router |                                              |
| TAILSCALE_ARGS    | Additional arguments passed to tailscale      | Optional                                     |

```
/container/envs
add name="tailscale" key="PASSWORD" value="xxxxxxxxxxxxxx"
add name="tailscale" key="DOMAIN" value="example.com"
add name="tailscale" key="AUTH_KEY" value="tskey-xxxxxxxxxxxxxxxxxxxxxxxx"
add name="tailscale" key="API_KEY" value="tskey-xxxxxxxxxxxxxxxxxxxxxxxx"
add name="tailscale" key="ADVERTISE_ROUTES" value="192.168.88.0/24"
add name="tailscale" key="CONTAINER_GATEWAY" value="172.17.0.1"
add name="tailscale" key="TAILSCALE_ARGS" value="--accept-routes"
```

6. Create the container

The container can be created via a registry or using the `tailscale.tar` file.

a. Container registry

Configure the registry URL and add the container.

```
/container/config 
set registry-url=https://ghcr.io tmpdir=disk1/pull

/container add remote-image=fluent-networks/tailscale-mikrotik:latest interface=veth1 envlist=tailscale root-dir=disk1/containers/tailscale start-on-boot=yes hostname=mikrotik dns=8.8.4.4,8.8.8.8
```

b. Tar archive file

Upload the `tailscale.tar` file to your router. Below we will assume the image is located at `disk1/tailscale.tar`

```
/container add file=disk1/tailscale.tar interface=veth1 envlist=tailscale root-dir=disk1/containers/tailscale start-on-boot=yes hostname=mikrotik dns=8.8.4.4,8.8.8.8
```

If you want to see the container output in the router log add `logging=yes` to the container add command. 

### Start the Container

Ensure the container has been extracted and added by verifying `status=stopped` using `/container/print` 

```
/container/start 0
```

### Verify Connectivity

In the Tailscale console, check the router is authenticated and enable the subnet routes. Your tailscale hosts should now be able to reach the router's LAN subnet. 

The container exposes a SSH server for management purposes using root credentials, and can be accessed via the router's tailscale address or the veth interface address.

## Upgrading

To upgrade, first stop and remove the container.

```
/container/stop 0
/container/remove 0
```

Create a new container as per Step 6. The tailscale.sh script detects if the tailscale machine exists and removes it using the Tailscale API. A new machine is then created with the same hostname.

In the Tailscale console, check the router is authenticated and enable the subnet routes.

## Contributing

We welcome suggestions and feedback from people interested in integrating Tailscale on the RouterOS platform. Please send a PR or create an issue if you're having any problems.



