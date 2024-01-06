// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract NFTLeverageStorageV1 {
    // constants
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    uint public constant LR_BASE = 10000;   // LTV ratio base, 10000 = 100%

    // upgrade
    string public version;

    uint256[50] private __upgradeGap;

    // lending
    address[] internal lendingAdapters;

    struct LeverageParams {
        address collateralAsset;    // The address of the collateral asset.
        uint256 collateralId;       // The ID of the collateral asset.
        uint256 targetLR;           // The target loan-to-value ratio of the position. e.g. 5000 = 50%.
        uint8 lendingIndex;         // The index of the lending adapter to use.
        address loanAsset;          // The address of the loan asset.
        bool toFragment;            // Whether to exchange the loan asset to fragment asset.
        uint8 fragmentIndex;        // The index of the fragment adapter to use.
        uint256 maxBorrowRate;      // The maximum borrow rate of the position. Expressed in ray. 0 means unlimited. e.g. 0.1 * 1e27 = 10%.
    }

    struct DeleverageParams {
        uint256 positionIndex;      // The index of the position to deleverage.
        uint256 deRatio;            // The target decrease ratio of the position. e.g. 5000 = 50%.
        uint256 maxRepayAmount;     // The maximum amount of the loan asset to repay. 0 means unlimited.
        bool exchangeFragment;      // Whether to exchange the fragment asset to loan asset.
    }

    struct LeveragedPosition {
        uint8 lendingIndex;         // The index of the lending adapter used.
        uint256 loanAmount;         // The amount of the loan asset.
        address loanAsset;          // The address of the loan asset.
        address collateralAsset;    // The address of the collateral asset.
        uint256 collateralId;       // The ID of the collateral asset.
        uint8 fragmentIndex;        // The index of the fragment adapter used.
        address fragmentAsset;      // The address of the fragment asset.
        uint256 fragmentAmount;     // The amount of the fragment asset.
    }

    LeveragedPosition[] internal leveragedPositions;

    uint256[50] private __lendingGap;

    // fragment
    address[] internal fragmentAdapters;

    uint256[50] private __fragmentGap;

    // price oracle
    address[] internal priceOracleAdapters;

    uint256[50] private __oracleGap;
}