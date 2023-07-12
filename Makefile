BTC_RPC_SERVER_ADDR?=127.0.0.1:8332

default: help

.PHONY: generate_bitcoind_conf
## generate_bitcoind_conf: generates the bitcoin.conf file from the bitcoin.template.conf. It will prompt for a password to be configured for your bitcoind rpc user.
generate_bitcoind_conf:
ifndef BTC_USER
	$(error BTC_USER is not provided. Usage: make generate_bitcoind_conf BTC_USER=something)
endif
	docker run -it --rm  -u "$(shell id -u)":"$(shell shell id -u)" -v "$(shell pwd)":/usr/src/myapp -w /usr/src/myapp python:3.12.0b3-alpine3.18 python rpcauth.py $(BTC_USER)

.PHONY: up
## up: starts the compose environment.
up:
	docker-compose up -d

.PHONY: down
## down: tears down the docker compose environment.
down:
	docker-compose down

.PHONY: env
## env: requires user to insert mandatory environment variables and dumps them to a `.env` file
env:
	@read -p "Enter the tailscale token: " token; \
	echo "TS_AUTHKEY=$$token" > .env

.PHONY: up_vpn
## up_vpn: starts the compose environment exposing the bitcoind node through tailscaled (VPN).
up_vpn:
	docker-compose --env-file ./.env -f docker-compose.yaml -f docker-compose.vpn.yaml up -d

.PHONY: down_vpn
## down_vpn: tears down the docker compose vpn environment.
down_vpn:
	docker-compose --env-file ./.env -f docker-compose.yaml -f docker-compose.vpn.yaml down

.PHONY: up_vpn_host
## up_vpn_host: starts VPN in the host system.
up_vpn_host:
	docker-compose --env-file ./.env -f docker-compose.hostvpn.yaml up -d

.PHONY: down_vpn_host
## down_vpn_host: tears down VPN in the host system.
up_vpn_host:
	docker-compose --env-file ./.env -f docker-compose.hostvpn.yaml up -d

.PHONY: test_btc_rpc
## test_btc_rpc: once the cluster is up, you can use this target to test RPC connectivity/authentication/authorization.
test_btc_rpc:
ifndef BTC_USER
	$(error BTC_USER is not provided. Usage: make test_btc_rpc BTC_USER=something)
endif
	curl --user $(BTC_USER) -w "\n\nHTTP Status: %{http_code}" --data-binary '{"jsonrpc":"1.0","id":"curltext","method":"getblockchaininfo","params":[]}' -H 'content-type:text/plain;' http://$(BTC_RPC_SERVER_ADDR)

.PHONY: test_btc_rpc_over_tor
## test_btc_rpc_over_tor: once the cluster is up, you can use this target to test RPC connectivity/authentication/authorization.
test_btc_rpc_over_tor:
ifndef BTC_USER
	$(error BTC_USER is not provided. Usage: make test_btc_rpc BTC_USER=something)
endif
ifndef BTC_RPC_SERVER_ONION_ADDR
	$(error BTC_RPC_SERVER_ONION_ADDR is not provided. Usage: make test_btc_rpc_over_tor BTC_RPC_SERVER_ONION_ADDR=something)
endif
	curl --socks5-hostname 127.0.0.1:9050  --user $(BTC_USER) -w "\n\nHTTP Status: %{http_code}" --data-binary '{"jsonrpc":"1.0","id":"curltext","method":"getblockchaininfo","params":[]}' -H 'content-type:text/plain;' http://$(BTC_RPC_SERVER_ONION_ADDR)

.PHONY: recycle_svc
## recycle_svc: recycle a service taking into account docker-compose.yaml configuration changes as well as service specific configuration changes (torrc, bitcoin.conf, etc)
recycle_svc:
ifndef SVC
	$(error SVC is not provided. Usage: make recycle_svc SVC=something)
endif
	docker-compose stop $(SVC)
	docker-compose rm -f $(SVC)
	docker-compose up -d --no-deps $(SVC)

.PHONY: restart_svc
## restart_svc: restarts a service. This will only refresh service-specific configurations (torrc, bitcoin.conf), and not docker-compose.yaml updates.
restart_svc:
ifndef SVC
	$(error SVC is not provided. Usage: make restart_svc SVC=something)
endif
	docker-compose restart $(SVC)

.PHONY: rotate_btc_user_credentials
## rotate_btc_user_credentials: rotates the credentials of the user configured to have access to bitcoind RPC APIs.
rotate_btc_user_credentials:
ifndef BTC_USER
	$(error BTC_USER is not provided. Usage: make testrotate_btc_user_credentials BTC_USER=something)
endif
	python rpcauth.py $(BTC_USER)

.PHONY: generate_service_spec
## generate_service_spec: generates the 'bitcoind.service' systemd specs replacing some environment parameters (project folder and user) 
generate_service_spec:
	cat bitcoind.template.service | sed "s/<USER>/$(shell whoami)/g" | sed "s|<PROJECT_DIR>|$(shell pwd)|g"  \
                | sed "s|<DOCKER_COMPOSE_PATH>|$(shell which docker-compose)|g" > bitcoind.service

.PHONY: help
## help: prints this help message.
help:
	@echo "Usage:"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'
