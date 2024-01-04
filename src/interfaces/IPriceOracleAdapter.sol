// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IPriceOracleAdapter
 * @dev Interface for a price oracle adapter contract.
 */
interface IPriceOracleAdapter {

    /**
     * @dev Returns the price of a token from one address to another.
     * @param _from The address of the token to convert from.
     * @param _to The address of the token to convert to.
     * @return The price of the token conversion.
     */
    function getPrice(address _from, address _to) external view returns (uint256);

    /**
     * @dev Returns the time-weighted average price (TWAP) of a token from one address to another over a specified period.
     * @param _from The address of the token to convert from.
     * @param _to The address of the token to convert to.
     * @param _period The time period in seconds over which to calculate the TWAP.
     * @return The TWAP of the token conversion.
     */
    function getTWAP(address _from, address _to, uint32 _period) external view returns (uint256);
}