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
import {UniswapV3Adapter} from "../src/adapters/oracle/UniswapV3Adapter.sol";
import {Errors} from "../src/libraries/Errors.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract NFTLeverageTest is ForkSetUp {
    address public toolDeployer;
    BendDAOAdapter bendDAOAdapter;
    FloorProtocolAdapter floorProtocolAdapter;
    UniswapV3Adapter uniswapV3Adapter;
    NFTLeverageV1 leverageV1;
    NFTLeverageProxy proxy;

    function setUp() public override {
        super.setUp();
        toolDeployer = makeAddr("toolDeployer");

        vm.startPrank(toolDeployer);
        bendDAOAdapter = new BendDAOAdapter();
        floorProtocolAdapter = new FloorProtocolAdapter();
        uniswapV3Adapter = new UniswapV3Adapter();
        vm.label(address(bendDAOAdapter), "bendDAOAdapter");
        vm.label(address(floorProtocolAdapter), "floorProtocolAdapter");
        vm.label(address(uniswapV3Adapter), "uniswapV3Adapter");
        leverageV1 = new NFTLeverageV1();
        vm.label(address(leverageV1), "leverageV1Implementation");
        vm.stopPrank();

        vm.startPrank(baycOwner);
        IERC721(BAYC).transferFrom(baycOwner, userA, 3287);
        vm.stopPrank();
        vm.startPrank(maycOwner);
        IERC721(MAYC).transferFrom(maycOwner, userA, 10306);
        vm.stopPrank();
        vm.startPrank(azukiOwner);
        IERC721(AZUKI).transferFrom(azukiOwner, userA, 3478);
        vm.stopPrank();
    }

    function testDeployProxy() public {
        vm.startPrank(userA);
        proxy = new NFTLeverageProxy(address(leverageV1), abi.encodeWithSignature("initializeV1(address,address,address)", address(bendDAOAdapter), address(floorProtocolAdapter), address(uniswapV3Adapter)));
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

        vm.startPrank(userA);
        NFTLeverageV1 nftLeverageV1 = NFTLeverageV1(address(proxy));
        uint _tokenId = 10306;
        IERC721(MAYC).approve(address(proxy), _tokenId);
        uint _targetLR = 5000; // 50%
        uint8 _lendingIndex = 0;
        bool _toFragment = true;
        uint8 _fragmentIndex = 0;
        uint _borrowAPR = nftLeverageV1.getBorrowAPR(MAYC, WETH, _lendingIndex);
        console2.log("borrow APR: %s", _borrowAPR);
        uint _maxBorrowRate = 0;
        address fragmentAsset = nftLeverageV1.getFragmentAsset(MAYC, _fragmentIndex);
        console2.log("NFT(%s) price: %s", MAYC, nftLeverageV1.getNftPrice(MAYC, _lendingIndex));
        console2.log("fragment asset: %s", fragmentAsset);
        console2.log("fragment price: %s", nftLeverageV1.getFragmentPrice(fragmentAsset, _fragmentIndex));
        console2.log("max LTV: %s", nftLeverageV1.getMaxLTV(MAYC, _lendingIndex));
        uint positionIndex = nftLeverageV1.leverage(NFTLeverageStorageV1.LeverageParams({
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
        assertEq(nftLeverageV1.totalLeveragedPositions(), 1, "mismatch prositons amount");
        console2.log("positionIndex: %s", positionIndex);
        NFTLeverageV1.LeveragedPosition memory position = nftLeverageV1.getLeveragePosition(positionIndex);
        console2.log("position.lendingIndex: %s", position.lendingIndex);
        console2.log("position.collateralAsset: %s", position.collateralAsset);
        console2.log("position.collateralId: %s", position.collateralId);
        console2.log("position.loanAsset: %s", position.loanAsset);
        console2.log("position.loanAmount: %s", position.loanAmount);
        console2.log("position.fragmentIndex: %s", position.fragmentIndex);
        console2.log("position.fragmentAsset: %s", position.fragmentAsset);
        console2.log("position.fragmentAmount: %s", position.fragmentAmount);
        console2.log("LTV: %s", nftLeverageV1.getLTV(positionIndex));
        console2.log("collateralValue: %s", nftLeverageV1.getCollateralValue(positionIndex));
        console2.log("debt: %s", nftLeverageV1.getDebt(positionIndex));
        console2.log("health factor: %s", nftLeverageV1.getHealthFactor(positionIndex));
        assertLe(nftLeverageV1.getLTV(positionIndex), _targetLR, "Mismatch LTV");
        assertGe(nftLeverageV1.getLTV(positionIndex), _targetLR - 1, "Mismatch LTV");
        vm.stopPrank();
    }

    function testLeverageMultipleAsset() public {
        testDeployProxy();
        // first
        testLeverage();
        // second
        vm.startPrank(userA);
        NFTLeverageV1 nftLeverageV1 = NFTLeverageV1(address(proxy));
        assertEq(nftLeverageV1.totalLeveragedPositions(), 1, "mismatch prositons amount");
        uint _tokenId = 3287;
        address _collateralAsset = BAYC;
        IERC721(_collateralAsset).approve(address(nftLeverageV1), _tokenId);
        uint _targetLR = 6000; // 60%
        uint8 _lendingIndex = 0;
        bool _toFragment = false;
        uint8 _fragmentIndex = 0;
        uint _maxBorrowRate = 22.5e25; // 22.5%
        uint positionIndex = nftLeverageV1.leverage(NFTLeverageStorageV1.LeverageParams({
            collateralAsset: _collateralAsset,
            collateralId: _tokenId,
            targetLR: _targetLR,
            lendingIndex: _lendingIndex,
            loanAsset: WETH,
            toFragment: _toFragment,
            fragmentIndex: _fragmentIndex,
            maxBorrowRate: _maxBorrowRate
        })
        );
        assertEq(nftLeverageV1.totalLeveragedPositions(), 2, "mismatch prositons amount");
        _tokenId = 3478;
        _collateralAsset = AZUKI;
        IERC721(_collateralAsset).approve(address(nftLeverageV1), _tokenId);
        _targetLR = 5000; // 50%
        _lendingIndex = 0;
        _toFragment = false;
        _fragmentIndex = 0;
        _maxBorrowRate = 22.5e25; // 22.5%
        positionIndex = nftLeverageV1.leverage(NFTLeverageStorageV1.LeverageParams({
            collateralAsset: _collateralAsset,
            collateralId: _tokenId,
            targetLR: _targetLR,
            lendingIndex: _lendingIndex,
            loanAsset: WETH,
            toFragment: _toFragment,
            fragmentIndex: _fragmentIndex,
            maxBorrowRate: _maxBorrowRate
        })
        );
        assertEq(nftLeverageV1.totalLeveragedPositions(), 3, "mismatch prositons amount");
        vm.stopPrank();
    }

    function testValidateLeverageParams() public {
        testDeployProxy();

        vm.startPrank(userA);
        NFTLeverageV1 nftLeverageV1 = NFTLeverageV1(address(proxy));
        uint _tokenId = 10306;
        uint _targetLR = 5000; // 50%
        uint8 _lendingIndex = 0;
        bool _toFragment = true;
        uint8 _fragmentIndex = 0;
        uint _maxBorrowRate = 0;
        vm.expectRevert(bytes(Errors.LEND_INVALID_LENDING_ADAPTER_INDEX));
        nftLeverageV1.leverage(NFTLeverageStorageV1.LeverageParams({
            collateralAsset: MAYC,
            collateralId: _tokenId,
            targetLR: _targetLR,
            lendingIndex: 100,
            loanAsset: WETH,
            toFragment: _toFragment,
            fragmentIndex: _fragmentIndex,
            maxBorrowRate: _maxBorrowRate
        })
        );

        vm.expectRevert(bytes(Errors.LEND_INVALID_NFT_ASSET_ADDRESS));
        nftLeverageV1.leverage(NFTLeverageStorageV1.LeverageParams({
            collateralAsset: address(0x01),
            collateralId: _tokenId,
            targetLR: _targetLR,
            lendingIndex: _lendingIndex,
            loanAsset: WETH,
            toFragment: _toFragment,
            fragmentIndex: _fragmentIndex,
            maxBorrowRate: _maxBorrowRate
        })
        );

        vm.expectRevert(bytes(Errors.LEND_INVALID_LOAN_ASSET_ADDRESS));
        nftLeverageV1.leverage(NFTLeverageStorageV1.LeverageParams({
            collateralAsset: MAYC,
            collateralId: _tokenId,
            targetLR: _targetLR,
            lendingIndex: _lendingIndex,
            loanAsset: address(0x01),
            toFragment: _toFragment,
            fragmentIndex: _fragmentIndex,
            maxBorrowRate: _maxBorrowRate
        })
        );

        vm.expectRevert(bytes(Errors.LEND_OVER_MAX_BORROW_RATE));
        nftLeverageV1.leverage(NFTLeverageStorageV1.LeverageParams({
            collateralAsset: MAYC,
            collateralId: _tokenId,
            targetLR: _targetLR,
            lendingIndex: _lendingIndex,
            loanAsset: WETH,
            toFragment: _toFragment,
            fragmentIndex: _fragmentIndex,
            maxBorrowRate: 5500 // 55%
        })
        );

        vm.stopPrank();
    }

    function testDeleverage() public {
        testLeverage();

        vm.startPrank(userA);
        NFTLeverageV1 nftLeverageV1 = NFTLeverageV1(address(proxy));
        // uniswap fee and slippage
        IERC20(WETH).approve(address(nftLeverageV1), 1 ether);
        uint _positionIndex = 0;
        uint _deRatio = 5000; // 50%
        uint _maxRepayAmount = 0;
        bool _exchangeFragment = true;
        nftLeverageV1.deleverage(NFTLeverageStorageV1.DeleverageParams({
            positionIndex: _positionIndex,
            deRatio: _deRatio,
            maxRepayAmount: _maxRepayAmount,
            exchangeFragment: _exchangeFragment
        }));
        assertEq(IERC721(MAYC).ownerOf(10306), userA, "Not fully deleveraged");
        vm.stopPrank();
    }

    function testDeleverageAfterOneDay() public {
        testLeverage();

        vm.startPrank(userA);
        NFTLeverageV1 nftLeverageV1 = NFTLeverageV1(address(proxy));
        vm.roll(block.number + 5760);   // ~1 day
        skip(86400);
        console2.log("================================================= After one day");
        uint positionIndex = 0;
        console2.log("positionIndex: %s", positionIndex);
        NFTLeverageV1.LeveragedPosition memory position = nftLeverageV1.getLeveragePosition(positionIndex);
        console2.log("position.lendingIndex: %s", position.lendingIndex);
        console2.log("position.collateralAsset: %s", position.collateralAsset);
        console2.log("position.collateralId: %s", position.collateralId);
        console2.log("position.loanAsset: %s", position.loanAsset);
        console2.log("position.loanAmount: %s", position.loanAmount);
        console2.log("position.fragmentIndex: %s", position.fragmentIndex);
        console2.log("position.fragmentAsset: %s", position.fragmentAsset);
        console2.log("position.fragmentAmount: %s", position.fragmentAmount);
        console2.log("LTV: %s", nftLeverageV1.getLTV(positionIndex));
        console2.log("collateralValue: %s", nftLeverageV1.getCollateralValue(positionIndex));
        console2.log("debt: %s", nftLeverageV1.getDebt(positionIndex));
        console2.log("health factor: %s", nftLeverageV1.getHealthFactor(positionIndex));
        // uniswap fee and slippage
        IERC20(WETH).approve(address(nftLeverageV1), 1 ether);
        uint _positionIndex = 0;
        uint _deRatio = 5500; // 55%
        uint _maxRepayAmount = 0;
        bool _exchangeFragment = true;
        nftLeverageV1.deleverage(NFTLeverageStorageV1.DeleverageParams({
            positionIndex: _positionIndex,
            deRatio: _deRatio,
            maxRepayAmount: _maxRepayAmount,
            exchangeFragment: _exchangeFragment
        }));
        assertEq(IERC721(position.collateralAsset).ownerOf(position.collateralId), userA, "Not fully deleveraged");
        vm.stopPrank();
    }

    function testDeleveragePartial() public {
        testLeverage();

        vm.startPrank(userA);
        NFTLeverageV1 nftLeverageV1 = NFTLeverageV1(address(proxy));
        uint totalPrositionsBefore = nftLeverageV1.totalLeveragedPositions();
        // uniswap fee and slippage
        IERC20(WETH).approve(address(nftLeverageV1), 1 ether);
        uint _positionIndex = 0;
        uint _deRatio = 1000; // 10%
        uint _maxRepayAmount = 0;
        bool _exchangeFragment = true;
        console2.log("================================================= first deleverage: %s", _deRatio);
        nftLeverageV1.deleverage(NFTLeverageStorageV1.DeleverageParams({
            positionIndex: _positionIndex,
            deRatio: _deRatio,
            maxRepayAmount: _maxRepayAmount,
            exchangeFragment: _exchangeFragment
        }));
        assertEq(nftLeverageV1.totalLeveragedPositions(), totalPrositionsBefore, "mismatch prositons amount");

        console2.log("After deleverage %s", _deRatio);
        console2.log("positionIndex: %s", _positionIndex);
        NFTLeverageV1.LeveragedPosition memory position = nftLeverageV1.getLeveragePosition(_positionIndex);
        console2.log("position.lendingIndex: %s", position.lendingIndex);
        console2.log("position.collateralAsset: %s", position.collateralAsset);
        console2.log("position.collateralId: %s", position.collateralId);
        console2.log("position.loanAsset: %s", position.loanAsset);
        console2.log("position.loanAmount: %s", position.loanAmount);
        console2.log("position.fragmentIndex: %s", position.fragmentIndex);
        console2.log("position.fragmentAsset: %s", position.fragmentAsset);
        console2.log("position.fragmentAmount: %s", position.fragmentAmount);
        console2.log("LTV: %s", nftLeverageV1.getLTV(_positionIndex));
        console2.log("collateralValue: %s", nftLeverageV1.getCollateralValue(_positionIndex));
        console2.log("debt: %s", nftLeverageV1.getDebt(_positionIndex));
        console2.log("health factor: %s", nftLeverageV1.getHealthFactor(_positionIndex));
        
        _deRatio = 4000; // 40%
        _exchangeFragment = false;
        console2.log("================================================= second deleverage: %s", _deRatio);
        nftLeverageV1.deleverage(NFTLeverageStorageV1.DeleverageParams({
            positionIndex: _positionIndex,
            deRatio: _deRatio,
            maxRepayAmount: _maxRepayAmount,
            exchangeFragment: _exchangeFragment
        }));
        assertEq(nftLeverageV1.totalLeveragedPositions(), totalPrositionsBefore - 1, "mismatch prositons amount");
        assertEq(IERC721(MAYC).ownerOf(10306), userA, "Not fully deleveraged");
        vm.stopPrank();
    }

    function testWithdraw() public {
        testDeployProxy();

        NFTLeverageV1 nftLeverageV1 = NFTLeverageV1(address(proxy));
        deal(address(nftLeverageV1), 1 ether);
        deal(WETH, address(nftLeverageV1), 1e18);
        vm.startPrank(baycOwner);
        IERC721(BAYC).transferFrom(baycOwner, address(nftLeverageV1), 197);
        vm.stopPrank();

        vm.startPrank(userA);
        nftLeverageV1.withdrawEthTo(payable(userA), 1e18);
        assertEq(address(nftLeverageV1).balance, 0, "mismatch ETH balance");
        nftLeverageV1.withdrawTo(userA, WETH, 1e18);
        assertEq(IERC20(WETH).balanceOf(address(nftLeverageV1)), 0, "mismatch WETH balance");
        nftLeverageV1.withdrawNftTo(userA, BAYC, 197);
        assertEq(IERC721(BAYC).ownerOf(197), userA, "mismatch NFT owner");
        vm.stopPrank();
    }
}