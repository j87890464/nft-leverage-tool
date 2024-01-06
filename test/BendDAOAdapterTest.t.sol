// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {BendDAOAdapter} from "../src/adapters/lending/BendDAOAdapter.sol";
import {ForkSetUp} from "./ForkSetUp.t.sol";
import {ILendPool} from "../src/interfaces/benddao/ILendPool.sol";
import {ILendPoolAddressesProvider} from "../src/interfaces/benddao/ILendPoolAddressesProvider.sol";

contract BendDAOAdapterTest is ForkSetUp {
    BendDAOAdapter bendDAOAdapter;
    address constant LEND_POOL = 0x70b97A0da65C15dfb0FFA02aEE6FA36e507C2762;

    function setUp() public override {
        super.setUp();
        bendDAOAdapter = new BendDAOAdapter();
        vm.label(LEND_POOL, "LEND_POOL");
    }

    function testIsNftSupported() public {
        assertEq(bendDAOAdapter.isNftSupported(MAYC), true);
        assertEq(bendDAOAdapter.isNftSupported(address(0x01)), false);
    }

    function testIsBorrowAssetSupported() public {
        assertEq(bendDAOAdapter.isBorrowAssetSupported(WETH), true);
        assertEq(bendDAOAdapter.isBorrowAssetSupported(address(0x01)), false);
    }

    function testGetFloorPrice() public {
        uint floorPrice = bendDAOAdapter.getFloorPrice(MAYC);
        console2.log("floorPrice of MAYC: %s", floorPrice);
        assertGt(floorPrice, 0);
        vm.expectRevert("NFTOracle: key not existed");
        bendDAOAdapter.getFloorPrice(address(0x01));
    }

    function testGetCollateralValue() public {
        uint tokenId = 16078;
        uint collateralValue = bendDAOAdapter.getCollateralValue(MAYC, tokenId);
        console2.log("collateralValue of MAYC#", tokenId, ":", collateralValue);
        assertGt(collateralValue, 0);
        tokenId = 10306;
        collateralValue = bendDAOAdapter.getCollateralValue(MAYC, tokenId);
        assertEq(collateralValue, 0);
    }

    function testGetDebt() public {
        uint tokenId = 16078;
        uint debt = bendDAOAdapter.getDebt(MAYC, tokenId);
        console2.log("debt of MAYC#", tokenId, ": ", debt);
        assertGt(debt, 0);
        tokenId = 10306;
        debt = bendDAOAdapter.getDebt(MAYC, tokenId);
        console2.log("debt of MAYC#", tokenId, ": ", debt);
        assertEq(debt, 0);
    }

    function testGetBorrowAPR() public {
        uint borrowAPR = bendDAOAdapter.getBorrowAPR(MAYC, WETH);
        console2.log("borrowAPR of MAYC(WETH):", borrowAPR);
        assertGt(borrowAPR, 0);
        borrowAPR = bendDAOAdapter.getBorrowAPR(address(0x01), WETH);
        assertEq(borrowAPR, 0);
        borrowAPR = bendDAOAdapter.getBorrowAPR(MAYC, address(0x01));
        assertEq(borrowAPR, 0);
    }

    function testGetLTV() public {
        uint tokenId = 16078;
        uint ltv = bendDAOAdapter.getLTV(MAYC, tokenId);
        console2.log("LTV of MAYC#", tokenId, ":", ltv);
        assertGt(ltv, 0);
        tokenId = 10306;
        ltv = bendDAOAdapter.getLTV(MAYC, tokenId);
        assertEq(ltv, 0);
    }

    function testGetMaxLTV() public {
        uint maxLTV = bendDAOAdapter.getMaxLTV(MAYC);
        console2.log("maxLTV of MAYC:", maxLTV);
        assertEq(maxLTV, 5000); // 50%
        vm.expectRevert("NFTOracle: key not existed");
        maxLTV = bendDAOAdapter.getMaxLTV(address(0x01));
    }

    function testGetHealthFactor() public {
        uint tokenId = 16078;
        uint healthFactor = bendDAOAdapter.getHealthFactor(MAYC, tokenId);
        console2.log("healthFactor of MAYC#", tokenId, ":", healthFactor);
        assertGt(healthFactor, 0);
        tokenId = 10306;
        healthFactor = bendDAOAdapter.getHealthFactor(MAYC, tokenId);
        assertEq(healthFactor, 0);
    }

    function testInstanceGetter() public {
        ILendPoolAddressesProvider lendPoolAddressesProvider = ILendPoolAddressesProvider(ILendPool(LEND_POOL).getAddressesProvider());
        assertEq(address(bendDAOAdapter.LendPoolAddressProvider()), address(lendPoolAddressesProvider));
        assertEq(address(bendDAOAdapter.LendPool()), address(lendPoolAddressesProvider.getLendPool()));
        assertEq(address(bendDAOAdapter.LendPoolLoan()), address(lendPoolAddressesProvider.getLendPoolLoan()));
        assertEq(address(bendDAOAdapter.NFTOracleGetter()), address(lendPoolAddressesProvider.getNFTOracle()));
        assertEq(address(bendDAOAdapter.BNFTRegistry()), address(lendPoolAddressesProvider.getBNFTRegistry()));
    }
}