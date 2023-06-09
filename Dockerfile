FROM ethereum/client-go:alltools-v1.10.17

WORKDIR /

COPY artifacts/ artifacts/

RUN mkdir bridge
RUN mkdir interfaces
RUN mkdir test

# Bridge contracts
RUN abigen --abi artifacts/abi/bridge/NerifBridge.sol/NerifBridge.json \
           --pkg nerifbridge \
           --type NerifBridge \
           --out bridge/nerifbridge.go

# Interfaces
RUN abigen --abi artifacts/abi/interfaces/INerifBridgeReceiver.sol/INerifBridgeReceiver.json \
           --pkg interfaces \
           --type INerifBridgeReceiver \
           --out interfaces/inerifbridgereceiver.go

# Test contracts
RUN abigen --abi artifacts/abi/test/TestReceiver.sol/TestReceiver.json \
           --pkg test \
           --type TestReceiver \
           --out test/testreceiver.go
