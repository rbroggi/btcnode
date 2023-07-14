# BTC Node

This repository, features some forms of self-hosting of bitcoin nodes:

It makes usage of docker-compose environments to host and expose different node configurations. 

The repository contains 3 branches, representing different hosting environments configurations:

1. [prune](https://github.com/rbroggi/btcnode/tree/prune): minimalist [bitcoind](https://en.bitcoin.it/wiki/Bitcoind) node pre-configured as 
a [prune node](https://bitcoin.org/en/full-node#reduce-storage).
2. [full](https://github.com/rbroggi/btcnode/tree/full): a full `bitcoind` node pre-configured to also
index transactions ([txindex=1](https://bitcoin.stackexchange.com/questions/35707/what-are-pros-and-cons-of-txindex-option)).
3. [electrs](https://github.com/rbroggi/btcnode/tree/electrs): a full `bitcoind` node with `txindex=1` along with an [electrs](https://github.com/romanz/electrs)
electrum server. 

In all configurations `bitcoind` operates in conjunction with [TOR](https://wiki.archlinux.org/title/tor)
for optimal security and anonymity. 

All configurations support 4 ways of exposing your `bitcoind` (and `electrs` when applicable) services:

1. `local` - service API only available in the node (`127.0.0.1`) where the docker-compose environment runs. 
2. `tor` - service API exposed using a tor hidden service through an onion address.
3. `vpn` - using [tailscale](https://tailscale.com/) service becomes available only in your VPN.
4. `all` - all of the above.

Notice that the option number `1.` can be used in conjunction with [ssh tunnel ports](https://linuxize.com/post/how-to-setup-ssh-tunneling/)
for remote access.
For an even stronger configuration, you can
[secure your sshd with FIDO2](https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html).

The default setup runs a prune version of the bitcoin node  

The optimal runtime environment for this service is a small server where you have the 
possibility to ssh into. 

## Config and run

the makefile should be your friend:

```shell
$ make
Usage:
  generate_bitcoind_conf        generates the bitcoin.conf file from the bitcoin.template.conf. It will prompt for a password to be configured for your bitcoind rpc user.
  up_local                      starts the compose environment where bitcoind is exposed locally to the node.
  down_local                    tears down the docker compose environment.
  .env                          requires user to insert mandatory environment variables and dumps them to a `.env` file.
  .env.host                     requires user to insert mandatory environment variables and dumps them to a `.env.host` file.
  up_vpn                        starts the compose environment exposing the bitcoind node through tailscaled (VPN).
  down_vpn                      tears down the docker compose vpn environment.
  up_tor                        starts the compose environment exposing the bitcoind node through tor hidden services.
  down_tor                      tears down the docker compose tor environment.
  up_all                        starts the compose environment exposing the bitcoind node locally, through VPN, and through tor hidden services.
  down_all                      tears down the docker compose all environment.
  up_vpn_host                   starts VPN in the host system.
  down_vpn_host                 tears down VPN in the host system.
  test_btc_rpc                  once the cluster is up, you can use this target to test RPC connectivity/authentication/authorization.
  test_btc_rpc_over_tor         once the cluster is up, you can use this target to test RPC connectivity/authentication/authorization.
  recycle_svc                   recycle a service taking into account docker-compose.base.yaml configuration changes as well as service specific configuration changes (torrc, bitcoin.conf, etc).
  restart_svc                   restarts a service. This will only refresh service-specific configurations (torrc, bitcoin.conf), and not docker-compose.base.yaml updates.
  rotate_btc_user_credentials   rotates the credentials of the user configured to have access to bitcoind RPC APIs.
  generate_service_spec         generates the 'bitcoind.service' systemd specs replacing some environment parameters (project folder and user).
  help                          prints this help message.
```

you would typically:

1. Checkout the branch that contains the configuration you are most interested in out of (`prune`, `full`, `electrs`);
2. Modify your `bitcoin/bitcoin.template.conf` and run:
  ```shell
  $ # This will prompt for some configurations and generate the bitcoind configuration file: `bitcoin/bitcoin.conf`
  $ make generate_bitcoind_conf BTC_USER=<your_btc_rpc_user>
  ```
3. Start the servers by running:
  ```shell
  $ # <remote_access_method> one of local, vpn, tor, all
  $ make up_<remote_access_method>
  ``` 
  > **_NOTE:_**  `vpn` and `all` require you to have configured a tailscale account and will prompt for an [emphemeral auth key](https://tailscale.com/kb/1085/auth-keys/)
  during the first run
4. If all goes well you can use `make generate_service_spec` to generate a 
  [systemd service spec](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
4. If you are satisfied with the systemd service specs you can 
[create a linux systemd service](https://medium.com/@benmorel/creating-a-linux-service-with-systemd-611b5c8b91d6)

## Word of caution

I have done some checks on the bitcoind docker image that I'm using, but that means that I inherently trust the image registry
to run this image, this might not be your case. [Don't trust, verify](https://thebitcoinmanual.com/btc-culture/glossary/dont-trust-verify/)!

## External access

### Using `local` mode and ssh tunnel

Start the compose environment: `make up_local`.

You need to have ssh access to the node where your docker-compose local stack is running.

To access your node, you can [ssh tunnel the port 8332](https://linuxize.com/post/how-to-setup-ssh-tunneling/) from
your local machine to the node (or VM) running the docker-compose environment, and then simply connect to the port
`8332`.

```shell
$ ssh -L 8332:localhost:8332 <your_user_name>@<remote_host>
```

Test that your node is reachable by running the following command from your client machine (not within the prompt you used to create the tunnel).

```shell
$ curl --user <your_btc_user>  --data-binary '{"jsonrpc":"1.0","id":"curltext","method":"getblockchaininfo","params":[]}' -H 'content-type:text/plain;' localhost:8332
```

or 

```shell
$ make test_btc_rpc BTC_USER=<your_btc_user> BTC_RPC_SERVER_ADDR=127.0.0.1:8332
```

> **_NOTE:_**  `<your_btc_user>` is the bitcoind user configured to authenticate against your btc node;


Pros:
* fast access;
* can protect your access using hardware-level ssh authentication;
Cons:
* If you are not in the same network as your node, you will have to port-forward your node to the public internet or enable VPN 
in your node running the docker-compose environment.

### Using `tor` mode

You can also Access your node through TOR network: `make up_tor`

Test that your node is reachable by running the following command:

```shell
curl --socks5-hostname <tor_proxy> --user <your_btc_user>  --data-binary '{"jsonrpc":"1.0","id":"curltext","method":"getblockchaininfo","params":[]}' -H 'content-type:text/plain;' <your_hidden_service_onion_address>:8332
```

or

```shell
$ make test_btc_rpc_over_tor BTC_USER=<your_btc_user> BTC_RPC_SERVER_ONION_ADDR=<your_hidden_service_onion_address>:8332
```

> **_NOTE:_**  `<tor_proxy>` is typically `127.0.0.1:9050` but you will have to know where it is running in your system;
> **_NOTE:_**  `<your_hidden_service_onion_address>` is the onion address of the `bitcoind_hidden` service, which can be found under `tor/bitcoin_hidden/hostname`;

PROS:
* No need to have access to a router to port-forward your node service;
* Accessible from anywhere as long as you have your onion address with you;
CONS:
* Very slow;

### Using `vpn` mode ([Tailscale](https://tailscale.com/))

You can also Access your node through VPN: `make up_vpn`

```shell
$ curl --user <your_btc_user>  --data-binary '{"jsonrpc":"1.0","id":"curltext","method":"getblockchaininfo","params":[]}' -H 'content-type:text/plain;' tailscaled:8332
```

or

```shell
$ make test_btc_rpc BTC_USER=<your_btc_user> BTC_RPC_SERVER_ADDR=tailscaled:8332
```

PROS:
* No need to have access to a router to port-forward your node service;
* Accessible from anywhere as long as you are in one of the workstations that can access your VPN
* Fast access;

### Using `local` mode and host VPN

You can also start your service locally with `make up_local` and separately start a VPN client in your
host with `make up_vpn_host`. With this approach, you can ssh-tunnel into your node even when not within 
the same network and use the same approach described in the [local mode section](#using-local-mode-and-ssh-tunnel)
(for that, your host needs to be running `sshd`, and you need admin privileges in the host).

PROS:
* No need to have access to a router to port-forward your node service;
* Accessible from anywhere as long as you are in one of the workstations that can access your VPN
* Fast access;

CONS:
* You need to have admin privileges on the host machine.

### Linux [mDNS](https://en.wikipedia.org/wiki/Multicast_DNS) for simplifying your local setup

When you only need to access your node from a client hosted in the same network, it is convenient
to start an `mDNS` in your node. Checkout for example [Avahi](https://wiki.archlinux.org/title/avahi).

This allows you to refer to your host with a local DNS name without worrying about having a fixed IP 
assigned to your node in your local network. As an alternative you could configure your home router to
assign a static IP to your node and edit your `/etc/hosts` file in the client to configure your node with 
an alias which is easier to remember than the local IP address. 

You can than simplify your ssh client configuration for tunneling by including the following content into
your `~/.ssh/config`

```shell
Host btcnode
  HostName <your-configured-mDNS-or-static-IP>
  User <your_user>
  Port <your_server_sshd_port_usually_22>
  IdentityFile <the_key_file_for_ssh_connection>
```

which allows you to login with simply:

```shell
ssh -L 8332:localhost:8332 btcnode
```

### Accessing the node from the internet

To access your node from the internet, you can configure port forwarding in your router
to forward your sshd port. This would allow you to ssh into your node and perform the tunneling technique
explained above using your public IP instead of your local `mDNS` address or your local network address.
If you don't plan to access your node from workstations that do not belong to your VPN, I would suggest
you to use the VPN approach as it gives you remote access without the need of port-forwarding (which opens 
a considerable attack vector).

Consider reading about best-practices whenever exposing your services to the internet.

If you configure properly your ssh daemon with a security key (e.g. [Yubikey](https://www.yubico.com/)) your ssh authentication would be protected 
by a hardware-device.

## Useful commands for monitoring prune node:

In your server running the docker-compose spec, it's handy to alias the following for interacting with
the `bitcoind` server running inside the docker-compose runtime:

```shell
alias bitcoin-cli='docker exec bitcoind bitcoin-cli
```

You can then check the status of your [blockchain info](https://developer.bitcoin.org/reference/rpc/getblockchaininfo.html):

```shell
$ bitcoin-cli getblockchaininfo
```

and if you have [jq](https://jqlang.github.io/jq/) installed you can monitor your oldest block in a typical prune node:

```shell
$ bitcoin-cli getblockchaininfo | jq '.pruneheight'
```

and also configure some kind of alert if it approaches too much a block-height that you are not willing to prune:

```shell
$ echo $(( <<<here_goes_the_block_height_you_are_interested>>> - $(bitcoin-cli getblockchaininfo | jq '.pruneheight')))
```

For more `bitcoin-cli` RPCs, refer to [this](https://developer.bitcoin.org/reference/rpc/index.html).

## Data

* `bitcoin/` folder is mounted in the `bitdoind` docker container, and it's where the blockchain is downloaded;
* `tailscale/btc/` folder will be used to persist VPN data from the `tailscaled` service. This will allow your
container to maintain the same node identity in the `tailscale` VPN;
* `tailscale/host/` serves the same purpose as the one above but for the `host-vpn` service which is dettached
from the main docker-compose environment;
* `tor/bitcoin_hidden/` will contain information about hidden-service exposed by tor - you can find your onion
address under this folder in a file called `hostname`.

## Use tor as SOCKS proxy 

If you want to consult some websites from your workstation hosted in the same network as the node above
you can leverage the tor proxy to mask your public IP address (at the price of having 
a less performant browsing experience). Check the documentation of your browser for how to configure a SOCKS 
proxy. The address of your proxy will be `<your-node-ip>:9050`. 

A legit reason/situation for doing that is when you want to check in [mem.pool](https://mempool.space/) for
a block that might contain a transaction that involves one of your wallets. You can consume the public service
in a convenient way without having to disclose your IP.

You can also use it in conjunction with `curl`:

```shell
$ curl --socks5-hostname <tor_proxy> ...
```

## References

* [host your hidden service with onion addresses](https://null-byte.wonderhowto.com/how-to/host-your-own-tor-hidden-service-with-custom-onion-address-0180159/)
* [TOR controller commands](https://stem.torproject.org/api/control.html#stem.control.Controller)
* [Running TOR proxy in docker](https://dev.to/nabarun/running-tor-proxy-with-docker-56n9)
    * simple way of running tor in docker, initial step for me to configure my solution.
* [Bitcoin core - running bitcoind and tor in Ubuntu VM](https://www.youtube.com/watch?v=fx_mLXISrfM&t=1599s). 
    * good details about how to configure systemd
* [Tor authentication and commands over telnet](https://gist.github.com/ndsamuelson/3c83f38ae470c82ff87d2653af11716b)
* [bitcoin.conf generation tool](https://jlopp.github.io/bitcoin-core-config-generator/)
* [ssh tunneling](https://linuxize.com/post/how-to-setup-ssh-tunneling/)
* [bitcoind RPC API Reference](https://developer.bitcoin.org/reference/rpc/)
* [bitcoind API list](https://en.bitcoin.it/wiki/Original_Bitcoin_client/API_calls_list)
* [enable debug log level in bitcoind](https://bitcoin.stackexchange.com/questions/66892/what-are-the-debug-categories)
* [Bitcoind configurations](https://riptutorial.com/bitcoin/example/26000/node-configuration)
* [TOR arguments](https://2019.www.torproject.org/docs/tor-manual.html.en)
* [Electrum servers comparison](https://sparrowwallet.com/docs/server-performance.html#:~:text=There%20is%20a%20vast%20difference,transactions%20associated%20with%20an%20address.)