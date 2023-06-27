BTC_USER?=bitcoin
BTC_RPC_SERVER_ADDR?=127.0.0.1:8332

.PHONY: rotate-btc-user-credentials
## rotate-btc-user-credentials: rotates the credentials of the user configured to have access to bitcoind RPC APIs.
rotate-btc-user-credentials:
	python rpcauth.py $(BTC_USER) -
		
.PHONY: test_btc_rpc
## test_btc_rpc: once the cluster is up, you can use this target to test RPC connectivity/authentication/authorization.
test_btc_rpc:
	curl --user $(BTC_USER) -w "\n\nHTTP Status: %{http_code}" --data-binary '{"jsonrpc":"1.0","id":"curltext","method":"getblockchaininfo","params":[]}' -H 'content-type:text/plain;' http://$(BTC_RPC_SERVER_ADDR)

.PHONY: recycle_svc
## recycle_svc: recycle a service taking into account docker-compose.yaml configuration changes as well as service specific configuration changes (torrc, bitcoin.conf, etc)
recycle_svc:
	docker-compose stop $(SVC)
	docker-compose rm -f $(SVC)
	docker-compose up -d --no-deps $(SVC)

.PHONY: up
## up: starts the compose environment.
up:
	docker-compose up -d

.PHONY: down
## down: tears down the docker compose environment.
down:
	docker-compose up -d

.PHONY: generate_service_spec
## generate_service_spec: generates the 'bitcoind.service' systemd specs replacing some environment parameters (project folder and user) 
generate_service_spec:
	cat bitcoind.template.service | sed "s/<USER>/$(shell whoami)/g" | sed "s|<PROJECT_DIR>|$(shell pwd)|g"  \
                | sed "s|<DOCKER_COMPOSE_PATH>|$(shell which docker-compose)|g" > bitcoind.service
