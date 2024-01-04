// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Test, console2} from "forge-std/Test.sol";
import {ForkSetUp} from "./ForkSetUp.t.sol";
import {NFTLeverageProxy} from "../src/main/NFTLeverageProxy.sol";
import {NFTLeverageV1} from "../src/main/NFTLeverageV1.sol";
import {NFTLeverageStorageV1} from "../src/main/NFTLeverageStorageV1.sol";
import {MockNFTLeverageV2} from "../src/main/mock/MockNFTLeverageV2.sol";
import {BendDAOAdapter} from "../src/adapters/lending/BendDAOAdapter.sol";
import {FloorProtocolAdapter} from "../src/adapters/fragment/FloorProtocolAdapter.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract NFTLeverageTest is ForkSetUp {
    address public toolDeployer;
    BendDAOAdapter bendDAOAdapter;
    FloorProtocolAdapter floorProtocolAdapter;
    NFTLeverageV1 leverageV1;
    NFTLeverageProxy proxy;

    function setUp() public override {
        super.setUp();
        toolDeployer = makeAddr("toolDeployer");

        vm.startPrank(toolDeployer);
        bendDAOAdapter = new BendDAOAdapter();
        floorProtocolAdapter = new FloorProtocolAdapter();
        vm.label(address(bendDAOAdapter), "bendDAOAdapter");
        vm.label(address(floorProtocolAdapter), "floorProtocolAdapter");
        leverageV1 = new NFTLeverageV1();
        vm.label(address(leverageV1), "leverageV1Implementation");
        vm.stopPrank();
    }

    function testDeployProxy() public {
        vm.startPrank(userA);
        proxy = new NFTLeverageProxy(address(leverageV1), abi.encodeWithSignature("initializeV1(address,address)", address(bendDAOAdapter), address(floorProtocolAdapter)));
        console2.log("proxy address: %s", address(proxy));
        vm.label(address(proxy), "NFTLeverageProxy");
        vm.stopPrank();
    }

    function testUpgrade() public {
        testDeployProxy();

        vm.startPrank(toolDeployer);
        MockNFTLeverageV2 leverageV2 = new MockNFTLeverageV2();
        vm.stopPrank();

        vm.startPrank(userA);
        NFTLeverageV1(address(proxy)).upgradeToAndCall(address(leverageV2), abi.encodeWithSignature("initializeV2()", ""));
        vm.stopPrank();

        assertEq(MockNFTLeverageV2(address(proxy)).version(), "v2");
        assertEq(MockNFTLeverageV2(address(proxy)).isV2(), true);
    }

    function testLeverage() public {
        testDeployProxy();

        vm.startPrank(maycOwner);
        uint _tokenId = 10306;
        IERC721(MAYC).balanceOf(maycOwner);
        IERC721(MAYC).ownerOf(_tokenId);
        IERC721(MAYC).transferFrom(maycOwner, userA, _tokenId);
        vm.stopPrank();

        vm.startPrank(userA);
        IERC721(MAYC).approve(address(proxy), _tokenId);
        uint _targetLR = 5000; // 50%
        uint8 _lendingIndex = 0;
        bool _toFragment = true;
        uint8 _fragmentIndex = 0;
        uint _maxBorrowRate = 0;
        NFTLeverageV1(address(proxy)).leverage(NFTLeverageStorageV1.LeverageParams({
            collateralAsset: MAYC,
            collateralId: _tokenId,
            targetLR: _targetLR,
            lendingIndex: _lendingIndex,
            loanAsset: WETH,
            toFragment: _toFragment,
            fragmentIndex: _fragmentIndex,
            maxBorrowRate: _maxBorrowRate
        })
        );
        vm.stopPrank();
    }

    function testDeleverage() public {
        testLeverage();

        vm.startPrank(userA);
        // uniswap fee and slippage
        IERC20(WETH).approve(address(proxy), 1 ether);
        uint _positionIndex = 0;
        uint _deRatio = 5000; // 50%
        uint _maxRepayAmount = 0;
        bool _exchangeFragment = true;
        NFTLeverageV1(address(proxy)).deleverage(NFTLeverageStorageV1.DeleverageParams({
            positionIndex: _positionIndex,
            deRatio: _deRatio,
            maxRepayAmount: _maxRepayAmount,
            exchangeFragment: _exchangeFragment
        }));
        vm.stopPrank();
    }
}