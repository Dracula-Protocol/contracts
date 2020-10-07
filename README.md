# Dracula Protocol contracts

## Core contracts

__MasterVampire__ [0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099](https://etherscan.io/address/0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099) implements the core logic behind Dracula Protocol.

__DraculaToken__ [0xb78B3320493a4EFaa1028130C5Ba26f0B6085Ef8](https://etherscan.io/address/0xb78b3320493a4efaa1028130c5ba26f0b6085ef8) ERC20-interface compliant token with minter set to __Master Vampire__ and vote-delegating functionality.

__IVampireAdapter__ interface that allows __Master Vampire__ to uniformly communicate with various target pools, effectively shadowing all the differences between them. Every victim's adapter smart-contract implements this interface. The interface also contains several informational methods that will be used in Governance for automatic reward redistribution.

__VampireAdapter__ is a helper library, that makes delegate calls from __Mater Vampire__ to target adapters.

## Adapters
There are several adapters to the most popular farming contracts. Every one of them is a separate contract that implements the __IVampireAdapter__ interface.

__SushiAdapter__ [0x5846b3A199d7746e6e4c06c95ddeEC299a18063a](https://etherscan.io/address/0x5846b3A199d7746e6e4c06c95ddeEC299a18063a)

__LuaAdapter__ [0x7E15Af078beCbb86af07Ebf59378DAA813cAf54C](https://etherscan.io/address/0x7E15Af078beCbb86af07Ebf59378DAA813cAf54C)

__UniswapAdapter__ [0x6E95fdEd84CA29F5c15501abcF10Fd7a410cE353](https://etherscan.io/address/0x6E95fdEd84CA29F5c15501abcF10Fd7a410cE353)

__PickleAdapter__ [0x5403fFd517dFe40BeF9A48997d0C6896Ed0c7f28](https://etherscan.io/address/0x5403fFd517dFe40BeF9A48997d0C6896Ed0c7f28)

__YfvAdapter__ [0xfD92F42bA498F7e86882C66f82eAC6547a2106f6](https://etherscan.io/address/0xfD92F42bA498F7e86882C66f82eAC6547a2106f6)
