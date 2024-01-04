// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract NFTLeverageStorageV1 {
    // constants
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    uint public constant LR_BASE = 10000;

    // upgrade section
    string public version;
    uint256[50] private __upgradeGap; // gap for upgrade safety

    // lending
    address[] internal lendingAdapters;

    struct LeverageParams {
        address collateralAsset;
        uint256 collateralId;
        uint256 targetLR;
        uint8 lendingIndex;
        address loanAsset;
        bool toFragment;
        uint8 fragmentIndex;
        uint256 maxBorrowRate;
    }

    struct DeleverageParams {
        uint256 positionIndex;
        uint256 deRatio;
        uint256 maxRepayAmount;
        bool exchangeFragment;
    }

    struct LeveragedPosition {
        uint8 lendingIndex;
        uint256 loanAmount;
        address loanAsset;
        address collateralAsset;
        uint256 collateralId;
        uint8 fragmentIndex;
        address fragmentAsset;
        uint256 fragmentAmount;
    }

    LeveragedPosition[] internal leveragedPositions;

    uint256[50] private __lendGap;

    // fragment
    address[] internal fragmentAdapters;

    uint256[50] private __fragmentGap;
}