BTC_RPC_SERVER_ADDR?=127.0.0.1:8332
DOCKER_COMPOSE_CMD := $(shell which docker-compose)
DOCKER_CMD := $(shell which docker)

default: help

.PHONY: dump_env
## dump_env: requires user to insert mandatory environment variables and dumps them to a `.env` file.
dump_env:
	@read -p "Enter the tailscale token if you intend to use vpn: " token && echo "TS_AUTHKEY='$$token'" > .env.tmp
	@echo "subnet masks currently under use: "
	@$(DOCKER_CMD) network ls -q | xargs $(DOCKER_CMD) network inspect --format='{{range .IPAM.Config}}{{.Subnet}}{{end}}' | tr -s '\n'
	@read -p "Optionally override docker subnet mask [default: 172.31.0.0/24]: " subnet \
		&& subnet=$${subnet:-172.31.0.0/24} \
		&& echo "DOCKER_SUBNET_MASK='$$subnet'" >> .env.tmp
	@read -p "Optionally override docker network gateway [default: 172.31.0.1]: " gateway \
		&& gateway=$${gateway:-172.31.0.1} \
		&& echo "DOCKER_NET_GATEWAY='$$gateway'" >> .env.tmp
	@read -p "Enter the username you intend to use to authenticate against bitcoind RPC calls: " username \
		&& echo "BTC_USER='$$username'" >> .env.tmp \
		&& $(DOCKER_CMD) run -it --rm  -v "$(shell pwd)":/usr/src/myapp -w /usr/src/myapp python:3.12.0b3-alpine3.18 python rpcauth.py $$username .env.tmp
	@echo "backing up existing .env if exist, error to be ignored"
	@-mv .env .env.bkp.$(shell date +"%Y%m%dT%H%M%S")
	@mv .env.tmp .env


.PHONY: .env
## .env: checks if .env file exists and if not invoke dump_env.
.env:
ifeq ("$(wildcard .env)","")
	@echo ".env file does not exist. Generating..."
	@$(MAKE) dump_env
else
	@echo ".env file exist. For regenerating run dump_env."
endif

.PHONY: generate_bitcoind_conf
## generate_bitcoind_conf: generates the bitcoin.conf file from the bitcoin.template.conf. It will prompt for a password to be configured for your bitcoind rpc user.
generate_bitcoind_conf: .env
	@source ./.env && \
		echo $$RPCAUTH && \
		cat bitcoin/bitcoin.template.conf \
		| sed "s@^rpcauth.*@rpcauth=$$RPCAUTH@g" \
		| sed "s@__DOCKER_SUBNET_MASK__@$$DOCKER_SUBNET_MASK@g" > bitcoin/bitcoin.conf

.PHONY: up_local
## up_local: starts the compose environment where bitcoind is exposed locally to the node.
up_local: .env
	$(DOCKER_COMPOSE_CMD) -f docker-compose.base.yaml -f docker-compose.local.yaml up -d

.PHONY: down_local
## down_local: tears down the docker compose environment.
down_local: .env
	$(DOCKER_COMPOSE_CMD) -f docker-compose.base.yaml -f docker-compose.local.yaml down

.PHONY: up_vpn
## up_vpn: starts the compose environment exposing the bitcoind node through tailscaled (VPN).
up_vpn: .env
	$(DOCKER_COMPOSE_CMD) --env-file ./.env -f docker-compose.base.yaml -f docker-compose.vpn.yaml up -d

.PHONY: down_vpn
## down_vpn: tears down the docker compose vpn environment.
down_vpn: .env
	$(DOCKER_COMPOSE_CMD) --env-file ./.env -f docker-compose.base.yaml -f docker-compose.vpn.yaml down

.PHONY: up_tor
## up_tor: starts the compose environment exposing the bitcoind node through tor hidden services.
up_tor: .env
	$(DOCKER_COMPOSE_CMD) --env-file ./.env -f docker-compose.base.yaml -f docker-compose.tor.yaml up -d

.PHONY: down_tor
## down_tor: tears down the docker compose tor environment.
down_tor: .env
	$(DOCKER_COMPOSE_CMD) --env-file ./.env -f docker-compose.base.yaml -f docker-compose.tor.yaml down

.PHONY: up_all
## up_all: starts the compose environment exposing the bitcoind node locally, through VPN, and through tor hidden services.
up_all: .env
	$(DOCKER_COMPOSE_CMD) --env-file ./.env -f docker-compose.base.yaml -f docker-compose.all.yaml up -d

.PHONY: down_all
## down_all: tears down the docker compose all environment.
down_all: .env
	$(DOCKER_COMPOSE_CMD) --env-file ./.env -f docker-compose.base.yaml -f docker-compose.all.yaml down

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
ifndef TOR_PROXY
	$(error TOR_PROXY is not provided. Usage: make test_btc_rpc_over_tor TOR_PROXY=something)
endif
	curl --socks5-hostname $(TOR_PROXY)  --user $(BTC_USER) -w "\n\nHTTP Status: %{http_code}" --data-binary '{"jsonrpc":"1.0","id":"curltext","method":"getblockchaininfo","params":[]}' -H 'content-type:text/plain;' http://$(BTC_RPC_SERVER_ONION_ADDR)

.PHONY: recycle_svc
## recycle_svc: recycle a service taking into account docker-compose.base.yaml configuration changes as well as service specific configuration changes (torrc, bitcoin.conf, etc).
recycle_svc:
ifndef SVC
	$(error SVC is not provided. Usage: make recycle_svc SVC=something)
endif
	$(DOCKER_COMPOSE_CMD) stop $(SVC)
	$(DOCKER_COMPOSE_CMD) rm -f $(SVC)
	$(DOCKER_COMPOSE_CMD) up -d --no-deps $(SVC)

.PHONY: restart_svc
## restart_svc: restarts a service. This will only refresh service-specific configurations (torrc, bitcoin.conf), and not docker-compose.base.yaml updates.
restart_svc:
ifndef SVC
	$(error SVC is not provided. Usage: make restart_svc SVC=something)
endif
	$(DOCKER_COMPOSE_CMD) restart $(SVC)

.PHONY: .env.host
## .env.host: requires user to insert mandatory environment variables and dumps them to a `.env.host` file.
.env.host:
	@read -p "Enter the tailscale token for host: " token; \
	echo "TS_AUTHKEY=$$token" > .env.host

.PHONY: up_vpn_host
## up_vpn_host: starts VPN in the host system.
up_vpn_host:
ifeq ("$(wildcard .env.host)","")
	@echo ".env.host file does not exist. Generating..."
	@$(MAKE) .env.host
endif
	$(DOCKER_COMPOSE_CMD) --env-file ./.env.host -f docker-compose.hostvpn.yaml up -d

.PHONY: down_vpn_host
## down_vpn_host: tears down VPN in the host system.
down_vpn_host:
	$(DOCKER_COMPOSE_CMD) --env-file ./.env.host -f docker-compose.hostvpn.yaml down

.PHONY: rotate_btc_user_credentials
## rotate_btc_user_credentials: rotates the credentials of the user configured to have access to bitcoind RPC APIs.
rotate_btc_user_credentials: .env
	@source ./.env && $(DOCKER_CMD) run -it --rm  -v "$(shell pwd)":/usr/src/myapp -w /usr/src/myapp python:3.12.0b3-alpine3.18 python rpcauth.py $$BTC_USER .env
	$(MAKE) generate_bitcoind_conf

.PHONY: generate_service_spec
## generate_service_spec: generates the 'bitcoind.service' systemd specs replacing some environment parameters (project folder and user).
generate_service_spec:
ifeq ("$(wildcard .env)","")
	@echo ".env file does not exist. Generating..."
	@$(MAKE) .env
endif
	@echo "Choose an option:"
	@echo "1. local only"
	@echo "2. tor only"
	@echo "3. vpn only"
	@echo "4. local, tor, and vpn"
	@read -p "Enter the option number (1-4): " option; \
	case $$option in \
		1) target_suffix="local";; \
		2) target_suffix="tor";; \
		3) target_suffix="vpn";; \
		4) target_suffix="all";; \
		*) echo "Invalid option"; exit 1;; \
	esac; \
	echo "$$target_suffix"; \
	cat bitcoind.template.service | sed "s/<USER>/$(shell whoami)/g" | sed "s|<PROJECT_DIR>|$(shell pwd)|g"  \
                | sed "s|<TARGET_SUFFIX>|$$target_suffix|g" > bitcoind.service

.PHONY: help
## help: prints this help message.
help:
	@echo "Usage:"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'
