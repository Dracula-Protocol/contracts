/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.12;

interface IDODOZoo {
    function getDODO(address baseToken, address quoteToken) external view returns (address);
}