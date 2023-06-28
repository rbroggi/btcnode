# BTC Node

This repo is basically a docker-compose environment featuring a 
[bitcoind](https://bitcoin.org/en/full-node#other-linux-daemon) operating in conjunction 
with [TOR](https://wiki.archlinux.org/title/tor)
for optimal security and anonimity. 

The default setup runs a prune version of the bitcoin node  

The optimal runtime environment for this service is a small server where you have the 
possibility to ssh into. 

For even greater security the bitcoin daemon only listens on `127.0.0.1` which means that 
for accessing it from wallets outside the node where the docker-compose cluster is running,
a user should first [ssh tunnel ports](https://linuxize.com/post/how-to-setup-ssh-tunneling/).

For an even stronger configuration, you can 
[secure your sshd with FIDO2](https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html). 

## Config and run

the makefile should be your friend:

```shell
❯ make
Usage:
  generate_bitcoind_conf        generates the bitcoin.conf file from the bitcoin.template.conf. It will prompt for a password to be configured for your bitcoind rpc user.
  up                            starts the compose environment.
  down                          tears down the docker compose environment.
  test_btc_rpc                  once the cluster is up, you can use this target to test RPC connectivity/authentication/authorization.
  recycle_svc                   recycle a service taking into account docker-compose.yaml configuration changes as well as service specific configuration changes (torrc, bitcoin.conf, etc)
  restart_svc                   restarts a service. This will only refresh service-specific configurations (torrc, bitcoin.conf), and not docker-compose.yaml updates.
  rotate_btc_user_credentials   rotates the credentials of the user configured to have access to bitcoind RPC APIs.
  generate_service_spec         generates the 'bitcoind.service' systemd specs replacing some environment parameters (project folder and user) 
  help                          prints this help message.
```

you would typically:

1. start by modifying your `bitcoin/bitcoin.template.conf`, then run the `make generate_bitcoind_conf BTC_USER=<your_btc_rpc_user>`.
2. `make up` -> this starts your btc node along with tor
3. If all goes well you can use `make generate_service_spec` to generate a 
  [systemd service spec](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
4. If you are satisfied with the systemd service specs you can 
[create a linux systemd service](https://medium.com/@benmorel/creating-a-linux-service-with-systemd-611b5c8b91d6)

## Word of caution

I have done some checks on the bitcoind docker image that I'm using, but that means that I inherently trust the image registry
to run this image, this might not be the your case. [Don't trust, verify](https://thebitcoinmanual.com/btc-culture/glossary/dont-trust-verify/)!

## External access

To access your node, you can [ssh tunnel the port 8332](https://linuxize.com/post/how-to-setup-ssh-tunneling/) from
your local machine to the node (or VM) running the docker-compose environment, and then simply connect to the port
`8332`.

## Data

`bitcoin` is mounted in the docker container, and it's where the blockchain is downloaded.

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
