.PHONY : commit upload repo install_devops install_brownie deploy clear

install_devops :; forge install cyfrin/foundry-devops@0.2.2 --no-commit

install_brownie :; forge install smartcontractkit/chainlink-brownie-contracts --no-commit

install_open:; forge install openzeppelin/openzeppelin-contracts --no-commit

repo:
	@echo "Enter repo name: "; \
	read msg; \
	gh repo create "$$msg" --public --source=. --remote=origin

upload:
	@git push -u origin main

commit:
	@echo "Enter commit message: "; \
	read msg; \
	git add .; \
	git commit -m "$$msg"


deployI:
	forge script script/Interactions.s.sol:fundFundMe --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast -vvvv

# dry run
deployF:
	forge script script/DeployFundMe.s.sol:DeployFundMe --fork-url wss://sepolia.gateway.tenderly.co

# Deploying the contract locally on anvil, private key is of anvil
deploy:
	@forge script script/DSCTEngine/DeployDSCTEngine.s.sol:DeployDSCTEngine --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

clear:
	@forge clean

# Debug Techniques
# 1. forge clean

#General Debugs
# 1. missing seperator
# => indentation OR :;
#
#
#
#
#
#
#
#
#

#################################
# General copy-paste things
# import {Script, console} from "lib/forge-std/src/Script.sol";
# import {Test, console} from "lib/forge-std/src/Test.sol";
# 
# 115792089237316195423570985008687907853269984665640564039457584007913129639936
