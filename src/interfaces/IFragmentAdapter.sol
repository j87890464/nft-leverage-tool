// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IFragmentAdapter
 * @dev Interface for a fragment adapter contract.
 */
interface IFragmentAdapter {
    /**
     * @dev Returns the fragment asset associated with the given NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @return The address of the fragment asset.
     */
    function getFragmentAsset(address _nftAsset) external view returns(address);

    /**
     * @dev Swaps a specified amount of a token to its corresponding fragment representation.
     * @param _tokenIn The address of the token to be swapped.
     * @param _amountIn The amount of the token to be swapped.
     * @param _nftAsset The address of the NFT asset associated with the token.
     * @return The amount of fragments received after the swap.
     */
    function swapToFragment(address _tokenIn, uint256 _amountIn, address _nftAsset) external returns(uint256);

    /**
     * @dev Swaps a specified amount of tokens from a fragment to the underlying asset.
     * @param _amountIn The amount of tokens to swap.
     * @param _nftAsset The address of the NFT asset.
     * @return The amount of tokens swapped.
     */
    function swapFromFragment(uint256 _amountIn, address _nftAsset) external returns(uint256);
}