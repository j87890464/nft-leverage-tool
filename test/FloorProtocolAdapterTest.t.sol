// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {FloorProtocolAdapter} from "../src/adapters/fragment/FloorProtocolAdapter.sol";
import {ForkSetUp} from "./ForkSetUp.t.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract FloorProtocolAdapterTest is ForkSetUp {
    FloorProtocolAdapter floorProtocolAdapter;
    address public constant microBAYC = 0x1e610De0D7ACfa1d820024948a91D96C5c9CE6B9;

    function setUp() public override {
        super.setUp();
        vm.startPrank(userA);
        floorProtocolAdapter = new FloorProtocolAdapter();
        vm.label(address(floorProtocolAdapter), "floorProtocolAdapter");
        vm.label(microBAYC, "microBAYC");
        vm.stopPrank();
    }

    function testGetFragmentAsset() public {
        vm.startPrank(userB);
        address fragmentAsset = floorProtocolAdapter.getFragmentAsset(BAYC);
        console2.log("fragmentAsset", fragmentAsset);
        assertEq(fragmentAsset, microBAYC);
        vm.stopPrank();
    }

    function testSwapToFragment() public {
        vm.startPrank(userB);
        IERC20(WETH).transfer(address(floorProtocolAdapter), 1e18);
        uint balanceBefore = IERC20(microBAYC).balanceOf(userB);
        uint256 amountOut = floorProtocolAdapter.swapToFragment(WETH, 1e18, BAYC);
        uint balanceAfter = IERC20(microBAYC).balanceOf(userB);
        console2.log("amountOut", amountOut);
        assertGt(amountOut, 0, "incorrect amountOut");
        assertEq(balanceAfter - balanceBefore, amountOut, "mismatch amount");
        vm.stopPrank();
    }

    function testSwapFromFragment() public {
        testSwapToFragment();

        vm.startPrank(userB);
        uint amountIn = IERC20(microBAYC).balanceOf(userB);
        IERC20(microBAYC).transfer(address(floorProtocolAdapter), amountIn);
        uint balanceBefore = IERC20(WETH).balanceOf(userB);
        uint256 amountOut = floorProtocolAdapter.swapFromFragment(amountIn, BAYC);
        uint balanceAfter = IERC20(WETH).balanceOf(userB);
        console2.log("amountOut", amountOut);
        assertGt(amountOut, 0, "incorrect amountOut");
        assertEq(balanceAfter - balanceBefore, amountOut, "mismatch amount");
        vm.stopPrank();
    }

    function testAddFragmentAsset() public {
        address asset = address(0x01);
        address microAsset = address(0x02);
        address v3Pool = address(0x03);
        uint24 fee = 3000;

        vm.startPrank(userB);
        vm.expectRevert();
        floorProtocolAdapter.addFragmentAsset(asset, microAsset, v3Pool, fee);
        vm.stopPrank();

        vm.startPrank(userA);
        floorProtocolAdapter.addFragmentAsset(asset, microAsset, v3Pool, fee);
        assertEq(floorProtocolAdapter.getFragmentAsset(asset), microAsset, "mismatch microAsset");
        ( , address _v3Pool, uint24 _fee) = floorProtocolAdapter.fragmentAssets(asset);
        assertEq(_v3Pool, v3Pool);
        assertEq(_fee, fee);
        vm.stopPrank();
    }
}