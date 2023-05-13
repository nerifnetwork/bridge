.PHONY: help
help: # Display this help
	@awk 'BEGIN{FS=":.*#";printf "Usage:\n  make <target>\n\nTargets:\n"}/^[a-zA-Z_-]+:.*?#/{printf"  %-10s %s\n",$$1,$$2}' $(MAKEFILE_LIST)

.PHONY: abigen
abigen: # Generate go files
	rm -rf artifacts/
	npm run compile
	npm run extract-abi
	docker build -t extract-abi .
	rm -rf pkg/*
	CONTAINER=`docker create extract-abi --name extract-abi`; \
	docker cp $$CONTAINER:/bridge pkg/bridge; \
	docker cp $$CONTAINER:/interfaces pkg/interfaces; \
	docker cp $$CONTAINER:/test pkg/test; \
	docker rm -v $$CONTAINER

.PHONY: init
init:
	cp .env.example .env
	cp contracts-<chain-id>.json contracts-5.json
	touch contracts-<chain-id>.json contracts-80001.json
	touch contracts-<chain-id>.json contracts-97.json
	touch contracts-<chain-id>.json contracts-10200.json
	touch contracts-<chain-id>.json contracts-59140.json

.PHONY: deploy
deploy: deploy-bridge deploy-receiver

.PHONY: deploy-bridge
deploy-bridge:
	VERIFY=true npx hardhat --network mumbai run scripts/deploy-bridge.ts
	VERIFY=true npx hardhat --network goerli run scripts/deploy-bridge.ts
	VERIFY=true npx hardhat --network bsc-testnet run scripts/deploy-bridge.ts
	VERIFY=true npx hardhat --network gnosis-chiado run scripts/deploy-bridge.ts
	VERIFY=true npx hardhat --network linea-testnet run scripts/deploy-bridge.ts

.PHONY: deploy-receiver
deploy-receiver:
	VERIFY=true npx hardhat --network mumbai run scripts/deploy-test-receiver.ts
	VERIFY=true npx hardhat --network goerli run scripts/deploy-test-receiver.ts
	VERIFY=true npx hardhat --network bsc-testnet run scripts/deploy-test-receiver.ts
	VERIFY=true npx hardhat --network gnosis-chiado run scripts/deploy-test-receiver.ts
	VERIFY=true npx hardhat --network linea-testnet run scripts/deploy-test-receiver.ts

.PHONY: send-message
send-message:
	npx hardhat --network goerli run scripts/send-message.ts
