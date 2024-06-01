# Wireguard-over-Websockets Config

This project explains the steps to enable a Wireguard VPN connection to be tunnelled over a secure websockets connection for use cases where outbound VPN traffic may be blocked/filtered/monitored.

The following steps assume that there is already a Wireguard connection established that is to be modified for tunnelling over WSS.

## Server Configuration

No modifications need to be made to the Wireguard server configuration itself, but `wstunnel` needs to be installed and configured as a systemd unit.

1. Download the latest wstunnel [release](https://github.com/erebe/wstunnel/releases)
2. Copy the binary to `/usr/local/bin/wstunnel`
3. Allow the binary to listen on privileged ports:

```bash
version="$(curl -sL https://api.github.com/repos/erebe/wstunnel/releases | grep -m1 -Po 'tag_name": "\K[^"]+')"
curl -sL "https://github.com/erebe/wstunnel/releases/download/${version}/wstunnel_${version/v/}_linux_amd64.tar.gz" > wstunnel.tar.gz
tar xvzf wstunnel.tar.gz
sudo install -Dm 0755 wstunnel /usr/local/bin/wstunnel
sudo setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/wstunnel
```

4. Create the following service file at `/etc/systemd/system/wstunnel.service`:

```bash
[Unit]
Description=Tunnel WG UDP over websocket
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/wstunnel server wss://0.0.0.0:443 --restrict-to 127.0.0.1:51820
Restart=no

[Install]
WantedBy=multi-user.target
```

5. Start and enable the service:

```bash
$ sudo systemctl enable wstunnel
$ sudo systemctl start wstunnel
```

If relying solely on the software firewall installed on the droplet, ensure that inbound traffic to port 443 is permitted.

## Client Configuration

Ensure dependencies are installed (debian-based example):

```
apt update && apt install -y curl jq
```

1. Download the latest wstunnel [release](https://github.com/erebe/wstunnel/releases)
2. Copy the binary to `/usr/local/bin/wstunnel`
3. Copy existing config to `/etc/wireguard/wss.conf`
4. Install `wstunnel.sh` to `/etc/wireguard/wstunnel.sh` [(script)](./wstunnel.sh)
5. Create a connection specific config file at `/etc/wireguard/wss.wstunnel` [(example)](./wss.wstunnel):

```
REMOTE_HOST=some.server.com
REMOTE_PORT=51820
UPDATE_HOSTS='/etc/hosts'

# Change if using nginx with custom prefix for added security
# WS_PREFIX='E7m5vGDqryd55MMP'

# Change if running WSS on a non-standard port, i.e. 4443
# WSS_PORT=443

# Can change local port of the wstunnel, don't forget to change Peer.Endpoint
# LOCAL_PORT=${REMOTE_PORT}

# If using dnsmasq can supply other file than /etc/hosts
# UPDATE_HOSTS='/usr/local/etc/dnsmasq.d/hosts/tunnels'

# Will send -HUP to dnsmasq to reload hosts
# USING_DNSMASQ=1
```

Next we will modify the client config to configure routing and point at the correct endpoint for our websockets tunnel. (Or cheat, and look at the [example config](./wss.conf))

1. Ensure the `Endpoint` directive is pointing at `127.0.0.1:51820`
2. Add the following lines to the `[Interface]` section:

```
Table = off
PreUp = source /etc/wireguard/wstunnel.sh && pre_up %i
PostUp = source /etc/wireguard/wstunnel.sh && post_up %i
PostDown = source /etc/wireguard/wstunnel.sh && post_down %i
```

## Finish

The tunnelling should now be configured - ensure the server is running and `wstunnel` is started on the server and initiate a connection - you should then be able to see the tunnel established by running `wg`.

Ensure that all files under `/etc/wireguard` are owned by root:

```
$ chown -R root: /etc/wireguard
$ chmod 600 /etc/wireguard/*
```
