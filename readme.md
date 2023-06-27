# BTC Node

This repo is basically a docker-compose environment featuring a [bitcoind](https://bitcoin.org/en/full-node#other-linux-daemon) operating in conjunction with [TOR](https://wiki.archlinux.org/title/tor)
for optimal security and anonimity. 

The default setup runs a prune version of the bitcoin node. 

The optimal runtimme environment for this service is a small server where you have the possibility to ssh into. 

For even greater security the bitcoin daemon only listens on `127.0.0.1` which means that for accessing it from wallets outside the node where the docker-compose cluster is running,
a user should first [ssh tunnel ports](https://linuxize.com/post/how-to-setup-ssh-tunneling/).

For an even stronger configuration, you can [secure your sshd with FIDO2](https://developers.yubico.com/SSH/Securing_SSH_with_FIDO2.html). 

## Config

Can be found under `.bitcoin/bitcoin.conf` and should be self-describing.

## Boot startup systemd

See the `bitcoind.service` file. It should be self-explanatory.

## External access

In the configuration file you have the instructions to regenerate the credentials for accessing the RPCs remotely.

## 

## Data

`.bitcoin` is mounted in the docker container and it's where the blockchain is downloaded.

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
