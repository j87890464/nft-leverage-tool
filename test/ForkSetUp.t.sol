// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract ForkSetUp is Test {
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    uint TARGET_BLOCK = 18_633_991;
    address public constant BENDDAO_PROXY = 0x70b97A0da65C15dfb0FFA02aEE6FA36e507C2762;
    address public constant LEND_POOL_ADDRESS_PROVIDER = 0x24451F47CaF13B24f4b5034e1dF6c0E401ec0e46;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant BAYC = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
    address public constant MAYC = 0x60E4d786628Fea6478F785A6d7e704777c86a7c6;
    address public constant AZUKI = 0xED5AF388653567Af2F388E6224dC7C4b3241C544;
    address public baycOwner = 0x020cA66C30beC2c4Fe3861a94E4DB4A498A35872;  // #3287
    address public maycOwner = 0x77811b6c55751E28522e3De940ABF1a7F3040235;  // #10306
    address public azukiOwner = 0x92657Fc9BbA9c0057bFA65fEA40000542f0Cc301; // #3478
    address public userA;
    address public userB;

    function setUp() public virtual {
        uint256 fork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(fork);
        vm.rollFork(TARGET_BLOCK);
        vm.label(BENDDAO_PROXY, "BENDDAO_PROXY");
        vm.label(LEND_POOL_ADDRESS_PROVIDER, "LEND_POOL_ADDRESS_PROVIDER");
        vm.label(WETH, "WETH");
        vm.label(BAYC, "BAYC");
        vm.label(MAYC, "MAYC");
        vm.label(AZUKI, "AZUKI");
        vm.label(baycOwner, "baycOwner");
        vm.label(maycOwner, "maycOwner");
        vm.label(azukiOwner, "azukiOwner");
        userA = makeAddr("userA");
        userB = makeAddr("userB");
        deal(userA, 100 ether);
        deal(WETH, userA, 100e18);
        deal(userB, 100 ether);
        deal(WETH, userB, 100e18);
    }
}