// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/ILendingAdapter.sol";
import {ILendPool} from "../../interfaces/benddao/ILendPool.sol";
import {ILendPoolAddressesProvider} from "../../interfaces/benddao/ILendPoolAddressesProvider.sol";
import {ILendPoolLoan} from "../../interfaces/benddao/ILendPoolLoan.sol";
import {INFTOracleGetter} from "../../interfaces/benddao/INFTOracleGetter.sol";
import {IBNFTRegistry} from "../../interfaces/benddao/IBNFTRegistry.sol";
import {IBNFT} from "../../interfaces/benddao/IBNFT.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

/**
 * @title BendDAOAdapter
 * @dev This contract implements the ILendingAdapter interface and serves as an adapter for interacting with the BendDAO lending protocol.
 */
contract BendDAOAdapter is ILendingAdapter {
    address public constant LEND_POOL_ADDRESS_PROVIDER = 0x24451F47CaF13B24f4b5034e1dF6c0E401ec0e46;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @dev Allows the caller to borrow a specified amount of a borrow asset by providing an NFT as collateral.
     * @param _nftAsset The address of the NFT asset used as collateral.
     * @param _tokenId The ID of the NFT token used as collateral.
     * @param _borrowAsset The address of the asset to be borrowed.
     * @param _borrowAmount The amount of the borrow asset to be borrowed.
     * @param _maxBorrowRate The maximum borrow rate allowed for the borrower.
     */
    function borrow(address _nftAsset, uint _tokenId, address _borrowAsset, uint _borrowAmount, uint _maxBorrowRate) external override {
        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory nftAssets = new address[](1);
        uint256[] memory nftTokenIds = new uint256[](1);
        assets[0] = _borrowAsset;
        uint _nftFloor = NFTOracleGetter().getAssetPrice(_nftAsset);
        amounts[0] = _borrowAmount;
        nftAssets[0] = _nftAsset;
        nftTokenIds[0] = _tokenId;
        IERC721(_nftAsset).approve(address(LendPool()), _tokenId);
        LendPool().batchBorrow(assets, amounts, nftAssets, nftTokenIds, address(this), 0);
    }

    /**
     * @dev Repays a specified amount of a loan for a given NFT asset and token ID.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The ID of the NFT token.
     * @param _repayAmount The amount to be repaid.
     */
    function repay(address _nftAsset, uint _tokenId, uint _repayAmount) external override {
        IERC20(WETH).approve(address(LendPool()), _repayAmount);
        LendPool().repay(_nftAsset, _tokenId, _repayAmount);
    }

    /**
     * @dev Checks if a specific NFT asset is supported by the lending protocol.
     * @param _nftAsset The address of the NFT asset.
     * @return A boolean indicating whether the NFT asset is supported.
     */
    function isNftSupported(address _nftAsset) external view override returns(bool) {

    }

    /**
     * @dev Checks if a specific borrow asset is supported by the lending protocol.
     * @param _borrowAsset The address of the NFT asset.
     * @return A boolean indicating whether the borrow asset is supported.
     */
    function isBorrowAssetSupported(address _borrowAsset) external view override returns(bool) {

    }

    /**
     * @dev Retrieves the floor price of an NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @return The floor price of the NFT asset.
     */
    function getFloorPrice(address _nftAsset) external view override returns(uint256) {
        return NFTOracleGetter().getAssetPrice(_nftAsset);
    }

    /**
     * @dev Returns the borrow balance of a specific NFT asset and token ID.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The token ID of the NFT.
     * @return The borrow balance of the NFT.
     */
    function getBorrowBalance(address _nftAsset, uint _tokenId) external override returns(uint256) {

    }

    /**
     * @dev Returns the debt of a specific NFT asset and token ID.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The token ID of the NFT.
     * @return The debt of the NFT.
     */
    function getDebt(address _nftAsset, uint _tokenId) external override returns(uint256) {
        uint _loanId = LendPoolLoan().getCollateralLoanId(_nftAsset, _tokenId);
        ( , uint _debt) = LendPoolLoan().getLoanReserveBorrowAmount(_loanId);

        return _debt;
    }

    /**
     * @dev Returns the annual percentage rate (APR) of a specific NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @return The APR of the NFT asset.
     */
    function getAPR(address _nftAsset) external view override returns(uint256) {

    }

    /**
     * @dev Returns the loan-to-value (LTV) ratio of a specific NFT asset and token ID.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The token ID of the NFT.
     * @return The LTV ratio of the NFT.
     */
    function getLTV(address _nftAsset, uint _tokenId) external view override returns(uint256) {

    }

    /**
     * @dev Returns the maximum loan-to-value (LTV) ratio of a specific NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @return The maximum LTV ratio of the NFT asset.
     */
    function getMaxLTV(address _nftAsset) external view override returns(uint256) {
        ( , , , , uint LTV, , ) = LendPool().getNftCollateralData(_nftAsset, WETH);

        return LTV;
    }

    /**
     * @dev Returns the health factor of a specific NFT asset and token ID.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The token ID of the NFT.
     * @return The health factor of the NFT.
     */
    function getHealthFactor(address _nftAsset, uint _tokenId) external view override returns(uint256) {

    }

    function LendPoolAddressProvider() public view returns (ILendPoolAddressesProvider) {
        return ILendPoolAddressesProvider(LEND_POOL_ADDRESS_PROVIDER);
    }

    function LendPool() public view returns (ILendPool) {
        return ILendPool(LendPoolAddressProvider().getLendPool());
    }

    function LendPoolLoan() public view returns (ILendPoolLoan) {
        return ILendPoolLoan(LendPoolAddressProvider().getLendPoolLoan());
    }

    function NFTOracleGetter() public view returns (INFTOracleGetter) {
        return INFTOracleGetter(LendPoolAddressProvider().getNFTOracle());
    }

    function BNFTRegistry() public view returns (IBNFTRegistry) {
        return IBNFTRegistry(LendPoolAddressProvider().getBNFTRegistry());
    }
}