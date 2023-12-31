// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NFTLeverageStorageV1} from "../NFTLeverageStorageV1.sol";

contract MockNFTLeverageStorageV2 is NFTLeverageStorageV1 {
    // v2 storage variables
    bool public isV2;
}