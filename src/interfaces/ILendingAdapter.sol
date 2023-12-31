// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ILendingAdapter
 * @dev Interface for interacting with lending adapters.
 */
interface ILendingAdapter {
    /**
     * @dev Allows a borrower to borrow a specified amount of a borrow asset using their NFT as collateral.
     * @param _nftAsset The address of the NFT asset used as collateral.
     * @param _tokenId The address of the specific NFT token used as collateral.
     * @param _borrowAsset The address of the asset to be borrowed.
     * @param _borrowAmount The amount of the borrow asset to be borrowed.
     * @param _maxBorrowRate The maximum borrow rate allowed for the loan.
     */
    function borrow(address _nftAsset, uint _tokenId, address _borrowAsset, uint _borrowAmount, uint _maxBorrowRate) external;

    /**
     * @dev Repays a specified amount of debt for a given NFT asset and token ID.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The ID of the NFT token.
     * @param _repayAmount The amount of debt to be repaid.
     */
    function repay(address _nftAsset, uint _tokenId, uint _repayAmount) external;

    /**
     * @dev Check if an NFT asset is supported by the lending adapter.
     * @param _nftAsset The address of the NFT asset.
     * @return A boolean indicating if the NFT asset is supported.
     */
    function isNftSupported(address _nftAsset) external view returns(bool);

    /**
     * @dev Check if a borrow asset is supported by the lending adapter.
     * @param _borrowAsset The address of the borrow asset.
     * @return A boolean indicating if the borrow asset is supported.
     */
    function isBorrowAssetSupported(address _borrowAsset) external view returns(bool);

    /**
     * @dev Returns the floor price of an NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @return The floor price of the NFT asset.
     */
    function getFloorPrice(address _nftAsset) external view returns(uint256);

    /**
     * @dev Get the borrow balance of an NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The ID of the NFT token.
     * @return The borrow balance of the NFT asset.
     */
    function getBorrowBalance(address _nftAsset, uint _tokenId) external returns(uint256);

    /**
     * @dev Get the debt of an NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The ID of the NFT token.
     * @return The debt of the NFT asset.
     */
    function getDebt(address _nftAsset, uint _tokenId) external returns(uint256);

    /**
     * @dev Get the annual percentage rate (APR) of an NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @return The APR of the NFT asset.
     */
    function getAPR(address _nftAsset) external view returns(uint256);

    /**
     * @dev Get the loan-to-value (LTV) ratio of an NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The ID of the NFT token.
     * @return The LTV ratio of the NFT asset.
     */
    function getLTV(address _nftAsset, uint _tokenId) external view returns(uint256);

    /**
     * @dev Get the maximum loan-to-value (LTV) ratio of an NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @return The maximum LTV ratio of the NFT asset.
     */
    function getMaxLTV(address _nftAsset) external view returns(uint256);

    /**
     * @dev Get the health factor of an NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The ID of the NFT token.
     * @return The health factor of the NFT asset.
     */
    function getHealthFactor(address _nftAsset, uint _tokenId) external view returns(uint256);
}