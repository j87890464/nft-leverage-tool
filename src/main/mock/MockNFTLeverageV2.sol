// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Errors} from "../../libraries/Errors.sol";
import {MockNFTLeverageStorageV2} from "./MockNFTLeverageStorageV2.sol";

contract MockNFTLeverageV2 is MockNFTLeverageStorageV2, UUPSUpgradeable, OwnableUpgradeable {
    function initializeV2() public {
        version = VERSION();
        isV2 = true;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyProxy {
        require(newImplementation != address(0), Errors.UG_INVALID_IMPLEMENTATION_ADDRESS);
    }

    function VERSION() public pure returns (string memory) {
        return "v2";
    }
}
