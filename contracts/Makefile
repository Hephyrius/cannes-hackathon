include .env

##
# Solidity Setup / Testing
##
.PHONY: install-foundry
install-foundry:
	curl -L https://foundry.paradigm.xyz | bash
	~/.foundry/bin/foundryup

.PHONY: deps
deps: clean-lib
	forge install --no-git github.com/foundry-rs/forge-std \
		github.com/OpenZeppelin/openzeppelin-contracts@v4.9.3 \
		github.com/OpenZeppelin/openzeppelin-contracts-upgradeable@v4.7.3 \
		
.PHONY: test
test:
	forge test test/e.sol --ffi -vvv  --fork-url https://ethereum-rpc.publicnode.com 


.PHONY: clean-lib
clean-lib:
	rm -rf lib
