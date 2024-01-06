// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {UniswapV3Adapter} from "../src/adapters/oracle/UniswapV3Adapter.sol";
import {ForkSetUp} from "./ForkSetUp.t.sol";

contract UniswapV3AdapterTest is ForkSetUp {
    UniswapV3Adapter uniswapV3Adapter;
    address constant MICRO_MAYC = 0x359108Ca299ca693502Ef217e2109aD02Aa4277C;

    function setUp() public override {
        super.setUp();
        uniswapV3Adapter = new UniswapV3Adapter();
        vm.label(address(uniswapV3Adapter), "uniswapV3Adapter");
    }

    function testGetPrice() public {
        vm.expectRevert();
        uniswapV3Adapter.getPrice(address(0x01), address(0x01));
        address from = MICRO_MAYC;
        address to = WETH;
        uint price = uniswapV3Adapter.getPrice(from, to);
        console2.log("price of %s to %s: %s", from, to, price);
        assertGt(price, 0, "Incorrect price");
        (from, to) = (to, from);
        price = uniswapV3Adapter.getPrice(from, to);
        console2.log("price of %s to %s: %s", from, to, price);
        assertGt(price, 0, "Incorrect price");
    }

    function testGetTWAP() public {
        vm.expectRevert();
        uniswapV3Adapter.getTWAP(address(0x01), address(0x01), 0);
        address from = MICRO_MAYC;
        address to = WETH;
        uint32 period = 3600; // 1 hour
        uint twap = uniswapV3Adapter.getTWAP(from, to, period);
        console2.log("TWAP of %s(period: %s): %s", from, period, twap);
        assertGt(twap, 0, "Incorrect TWAP");
        (from, to) = (to, from);
        twap = uniswapV3Adapter.getTWAP(from, to, period);
        console2.log("TWAP of %s(period: %s): %s", from, period, twap);
        assertGt(twap, 0, "Incorrect TWAP");
        period = 0; // current price
        twap = uniswapV3Adapter.getTWAP(from, to, period);
        console2.log("TWAP of %s(period: %s): %s", from, period, twap);
        assertGt(twap, 0, "Incorrect TWAP");
        period = type(uint32).max; // longest period of the pool
        twap = uniswapV3Adapter.getTWAP(from, to, period);
        console2.log("TWAP of %s(period: %s): %s", from, period, twap);
        assertGt(twap, 0, "Incorrect TWAP");
    }
}