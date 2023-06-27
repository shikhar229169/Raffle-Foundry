# Raffle-Foundry
This repository contains the Raffle project in Foundry Framework. It uses chainlink automation to select a winner automatically after certain interval and chainlink VRF to get random number and choose a winner.

## Quickstart
```
git clone https://github.com/shikhar229169/Raffle-Foundry.git
cd Raffle-Foundry
forge build
```

# Usage
## Start a Local Node
```
anvil
```

## Chainlink-Library
```
forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit
```

## Deploy on Mumbai Network
```
forge script script/DeployRaffle.s.sol --rpc-url $MUMBAI_RPC_URL --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_API_KEY --broadcast
```

## Deploy on Anvil
```
forge script script/DeployRaffle.s.sol --rpc-url $RPC_URL --private-key $ANVIL_PRIVATE_KEY --broadcast
```

## Test on anvil
```
forge test
```

## Test on fork mumbai network
```
forge test --fork-url $MUMBAI_RPC_URL
```

## Test Coverage
```
forge coverage
```
