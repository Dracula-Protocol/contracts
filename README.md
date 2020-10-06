# Dracula Protocol contracts

## Core contracts

__MasterVampire__ [0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099](https://etherscan.io/address/0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099) implements the core logic behind Dracula Protocol.

__DraculaToken__ [0xb78B3320493a4EFaa1028130C5Ba26f0B6085Ef8](https://etherscan.io/address/0xb78b3320493a4efaa1028130c5ba26f0b6085ef8) ERC20-interface compliant token with minter set to __Master Vampire__ and vote-delegating functionality.

__IVampireAdapter__ interface that allows __Master Vampire__ to uniformly communicate with various target pools, effectively shadowing all the differences between them. Every victim's adapter smart-contract implements this interface. The interface also contains several informational methods that will be used in Governance for automatic reward redistribution.

__VampireAdapter__ is a helper library, that makes delegate calls from __Mater Vampire__ to target adapters.

## Adapters
There are several adapters to the most popular farming contracts. Every one of them is a separate contract that implements the __IVampireAdapter__ interface.

__SushiAdapter__ [0xeb583Aaf4F35b84E49ee159D6dcb4a04e4a2a8b5](https://etherscan.io/address/0xeb583Aaf4F35b84E49ee159D6dcb4a04e4a2a8b5)

__LuaAdapter__ [0x6f4C7A4fd0122016868333769a468068e72B2c48](https://etherscan.io/address/0x6f4C7A4fd0122016868333769a468068e72B2c48)

__UniswapAdapter__ [0x6E95fdEd84CA29F5c15501abcF10Fd7a410cE353](https://etherscan.io/address/0x6E95fdEd84CA29F5c15501abcF10Fd7a410cE353)

__PickleAdapter__ [0x04a812FB7F02Ae13f6267B7bA30B5598a7F6E0eB](https://etherscan.io/address/0x04a812FB7F02Ae13f6267B7bA30B5598a7F6E0eB)

__YfvAdapter__ [0x5e8Cc25e7BbA1479CEE17604B72e8Bd64739E3c3](https://etherscan.io/address/0x5e8Cc25e7BbA1479CEE17604B72e8Bd64739E3c3)
