// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NFTLeverageProxy is ERC1967Proxy {
    constructor(address initialImplementation, bytes memory initData) ERC1967Proxy(initialImplementation, initData) {
    }
}
