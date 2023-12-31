// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {Test, console2} from "forge-std/Test.sol";
import {NFTLeverageProxy} from "../src/main/NFTLeverageProxy.sol";
import {NFTLeverageV1} from "../src/main/NFTLeverageV1.sol";
import {NFTLeverageStorageV1} from "../src/main/NFTLeverageStorageV1.sol";
import {MockNFTLeverageV2} from "../src/main/mock/MockNFTLeverageV2.sol";
import {BendDAOAdapter} from "../src/adapters/lending/BendDAOAdapter.sol";
import {FloorProtocolAdapter} from "../src/adapters/fragment/FloorProtocolAdapter.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract NFTLeverageProxyTest is Test {
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    address public constant BENDDAO_PROXY = 0x70b97A0da65C15dfb0FFA02aEE6FA36e507C2762;
    address public borrower = 0x77811b6c55751E28522e3De940ABF1a7F3040235;
    address public constant LEND_POOL_ADDRESS_PROVIDER = 0x24451F47CaF13B24f4b5034e1dF6c0E401ec0e46;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant MAYC = 0x60E4d786628Fea6478F785A6d7e704777c86a7c6;
    address public userA;
    address public toolDeployer;
    BendDAOAdapter bendDAOAdapter;
    FloorProtocolAdapter floorProtocolAdapter;
    NFTLeverageV1 leverageV1;

    function setUp() public {
        uint256 fork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(fork);
        vm.rollFork(18_633_991);
        vm.label(borrower, "Borrower-A");
        vm.label(WETH, "WETH");
        userA = makeAddr("userA");
        deal(userA, 100 ether);
        deal(WETH, userA, 100 ether);

        vm.startPrank(toolDeployer);
        bendDAOAdapter = new BendDAOAdapter();
        floorProtocolAdapter = new FloorProtocolAdapter();
        vm.label(address(bendDAOAdapter), "bendDAOAdapter");
        vm.label(address(floorProtocolAdapter), "floorProtocolAdapter");
        leverageV1 = new NFTLeverageV1();
        vm.label(address(leverageV1), "leverageV1Implementation");
        vm.stopPrank();
    }

    function testUpgrade() public {
        vm.startPrank(toolDeployer);
        NFTLeverageProxy proxy = new NFTLeverageProxy(address(leverageV1), abi.encodeWithSignature("initializeV1(address,address)", address(0x01), address(0x01)));
        console2.log("proxy address: %s", address(proxy));

        MockNFTLeverageV2 leverageV2 = new MockNFTLeverageV2();
        NFTLeverageV1(address(proxy)).upgradeToAndCall(address(leverageV2), abi.encodeWithSignature("initializeV2()", ""));

        assertEq(MockNFTLeverageV2(address(proxy)).version(), "v2");
        assertEq(MockNFTLeverageV2(address(proxy)).isV2(), true);
        vm.stopPrank();
    }

    function testNFTLeverageV1() public {
        vm.startPrank(borrower);
        uint _tokenId = 10306;
        IERC721(MAYC).balanceOf(borrower);
        IERC721(MAYC).ownerOf(_tokenId);
        IERC721(MAYC).transferFrom(borrower, userA, _tokenId);
        vm.stopPrank();

        vm.startPrank(userA);
        NFTLeverageProxy proxy = new NFTLeverageProxy(address(leverageV1), abi.encodeWithSignature("initializeV1(address,address)", address(bendDAOAdapter), address(floorProtocolAdapter)));
        vm.label(address(proxy), "NFTLeverageProxy");
        console2.log("proxy address: %s", address(proxy));
        IERC721(MAYC).setApprovalForAll(address(proxy), true);
        uint _targetLR = 1000;
        NFTLeverageV1(address(proxy)).createLeverage(NFTLeverageStorageV1.LeverageParams({
            collateralAsset: MAYC,
            collateralId: _tokenId,
            targetLR: _targetLR,
            lendingIndex: 0,
            loanAsset: WETH,
            toFragment: true,
            fragmentIndex: 0,
            maxBorrowRate: 0
        })
        );
        // uniswap fee and slippage
        IERC20(WETH).approve(address(proxy), 3.179e15);

        NFTLeverageV1(address(proxy)).removeLeverage(0);
        vm.stopPrank();
    }
}