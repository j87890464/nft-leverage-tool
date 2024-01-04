// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPriceOracleAdapter} from "../../interfaces/IPriceOracleAdapter.sol";
import {IUniswapV3Pool} from "v3-core/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "v3-core/interfaces/IUniswapV3Factory.sol";
import "v3-core/libraries/TickMath.sol";
import "v3-core/libraries/FixedPoint96.sol";
import "v3-core/libraries/FullMath.sol";

/**
 * @title UniswapV3PriceOracleAdapter
 * @dev This contract is an adapter for interacting with the Uniswap V3 price oracle.
 */
contract UniswapV3PriceOracleAdapter is IPriceOracleAdapter {
    address public constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    uint24 public constant FEE_03 = 3000; // 0.3%

    /**
     * @dev Get the price of a token pair with a default fee of 0.3%.
     * @param _from The address of the token to convert from.
     * @param _to The address of the token to convert to.
     * @return The price of the token pair.
     */
    function getPrice(address _from, address _to) public view override returns (uint256) {
        return getPrice(_from, _to, FEE_03);
    }

    /**
     * @dev Get the price of a token pair with a specified fee.
     * @param _from The address of the token to convert from.
     * @param _to The address of the token to convert to.
     * @param _fee The fee to use for the conversion.
     * @return The price of the token pair.
     */
    function getPrice(address _from, address _to, uint24 _fee) public view returns (uint256) {
        return _getPrice(_from, _to, _fee);
    }

    /**
     * @dev Get the time-weighted average price (TWAP) of a token pair with a default fee of 0.3% over a specified period.
     * @param _from The address of the token to convert from.
     * @param _to The address of the token to convert to.
     * @param _period The period over which to calculate the TWAP.
     * @return The TWAP of the token pair.
     */
    function getTWAP(address _from, address _to, uint32 _period) public view override returns (uint256) {
        return getTWAP(_from, _to, FEE_03, _period);
    }

    /**
     * @dev Get the time-weighted average price (TWAP) of a token pair with a specified fee over a specified period.
     * @param _from The address of the token to convert from.
     * @param _to The address of the token to convert to.
     * @param _fee The fee to use for the conversion.
     * @param _period The period over which to calculate the TWAP.
     * @return The TWAP of the token pair.
     */
    function getTWAP(address _from, address _to, uint24 _fee, uint32 _period) public view returns (uint256) {
        return _getTWAP(_from, _to, _fee, _period);
    }

    /**
     * @dev Internal function to get the price of a token pair with a specified fee.
     * @param _from The address of the token to convert from.
     * @param _to The address of the token to convert to.
     * @param _fee The fee to use for the conversion.
     * @return The price of the token pair.
     */
    function _getPrice(address _from, address _to, uint24 _fee) internal view returns (uint256) {
        // Get pool, token0, and token1
        IUniswapV3Pool pool = IUniswapV3Pool(IUniswapV3Factory(FACTORY).getPool(_from, _to, _fee));
        address token0 = pool.token0();
        address token1 = pool.token1();
        require(_from == token0 || _from == token1, "Invalid _from");

        // Get current price
        (, int24 tick, , , , , ) = pool.slot0();
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
        require(sqrtPriceX96 > 0, "Invalid sqrtPriceX96");
        uint256 price = FullMath.mulDiv(uint256(sqrtPriceX96), uint256(sqrtPriceX96), FixedPoint96.Q96);

        // If the _from address is token1, invert the price
        if (_from == token1) {
            price = _reciprocal(price);
        }
        
        return price;
    }

    /**
     * @dev Internal function to get the time-weighted average price (TWAP) of a token pair with a specified fee over a specified period.
     * @param _from The address of the token to convert from.
     * @param _to The address of the token to convert to.
     * @param _fee The fee to use for the conversion.
     * @param _period The period over which to calculate the TWAP.
     * @return The TWAP of the token pair.
     */
    function _getTWAP(address _from, address _to, uint24 _fee, uint32 _period) internal view returns (uint256) {
        // Get pool, token0, and token1
        IUniswapV3Pool pool = IUniswapV3Pool(IUniswapV3Factory(FACTORY).getPool(_from, _to, _fee));
        address token0 = pool.token0();
        address token1 = pool.token1();
        require(_from == token0 || _from == token1, "Invalid _from");
        (, , uint16 observationIndex, uint16 observationCardinality, , , ) = pool.slot0();
        (uint32 targetTimestamp, , , bool initialized) = pool.observations((observationIndex + 1) % observationCardinality);
        if (!initialized) {
            (targetTimestamp, , , ) = pool.observations(0);
        }
        uint32 timestampDiff = uint32(block.timestamp) - targetTimestamp;

        // Get TWAP
        uint twap;
        if (timestampDiff == 0) {
            // return the current price
            return _getPrice(_from, _to, _fee);
        } else {
            if (timestampDiff < _period) {
                _period = timestampDiff;
            }
            twap = _getPriceX96FromSqrtPriceX96(_getSqrtTwapX96(address(pool), _period));
        }
        
        // If the _from address is token1, invert the price
        if (_from == token1) {
            twap = _reciprocal(twap);
        }

        return twap;
    }

    /**
     * @dev Internal function to get the square root of the time-weighted average price (TWAP) of a token pair over a specified period.
     * @param _uniswapV3Pool The address of the Uniswap V3 pool.
     * @param _period The period over which to calculate the TWAP.
     * @return sqrtPriceX96 The square root of the TWAP of the token pair.
     */
    function _getSqrtTwapX96(address _uniswapV3Pool, uint32 _period) internal view returns (uint160 sqrtPriceX96) {
        if (_period == 0) {
            // return the current price if _period == 0
            (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(_uniswapV3Pool).slot0();
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = _period; // before
            secondsAgos[1] = 0; // now
            (int56[] memory tickCumulatives, ) = IUniswapV3Pool(_uniswapV3Pool).observe(secondsAgos);

            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
                int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(_period)))
            );
        }
    }

    /**
     * @dev Internal function to convert the square root price to the price.
     * @param sqrtPriceX96 The square root price.
     * @return priceX96 The price.
     */
    function _getPriceX96FromSqrtPriceX96(uint160 sqrtPriceX96) internal pure returns(uint256 priceX96) {
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
    }

    /**
     * @dev Internal function to calculate the reciprocal of a number.
     * @param x The number to calculate the reciprocal of.
     * @return The reciprocal of the number.
     */
    function _reciprocal(uint256 x) internal pure returns (uint256) {
        require(x > 0);
        return (FixedPoint96.Q96 * FixedPoint96.Q96) / x;
    }
}
