// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {ILendPool} from "bend-lending-protocol/interfaces/ILendPool.sol";
import {ILendPoolAddressesProvider} from "bend-lending-protocol/interfaces/ILendPoolAddressesProvider.sol";
import {ILendPoolLoan} from "bend-lending-protocol/interfaces/ILendPoolLoan.sol";
import {INFTOracleGetter} from "bend-lending-protocol/interfaces/INFTOracleGetter.sol";
import {IBNFTRegistry} from "bend-lending-protocol/interfaces/IBNFTRegistry.sol";
import {IBNFT} from "bend-lending-protocol/interfaces/IBNFT.sol";

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

interface IERC721 is IERC165 {
    function balanceOf(address owner) external view returns (uint balance);

    function ownerOf(uint tokenId) external view returns (address owner);

    function safeTransferFrom(address from, address to, uint tokenId) external;

    function safeTransferFrom(
        address from,
        address to,
        uint tokenId,
        bytes calldata data
    ) external;

    function transferFrom(address from, address to, uint tokenId) external;

    function approve(address to, uint tokenId) external;

    function getApproved(uint tokenId) external view returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);
}

contract BendDAOTest is Test {
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    address public maycOwner = 0x77811b6c55751E28522e3De940ABF1a7F3040235;
    address public constant BENDDAO_PROXY = 0x70b97A0da65C15dfb0FFA02aEE6FA36e507C2762;
    address public constant LEND_POOL_ADDRESS_PROVIDER = 0x24451F47CaF13B24f4b5034e1dF6c0E401ec0e46;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant MAYC = 0x60E4d786628Fea6478F785A6d7e704777c86a7c6;
    address public bMAYC;
    address public nftOracle;
    address public userA;
    ILendPoolAddressesProvider lendPoolAddressesProvider;
    ILendPoolLoan lendPoolLoan;
    ILendPool lendPool;
    INFTOracleGetter NFTOracleGetter;
    IBNFTRegistry bNFTRegistry;

    function setUp() public {
        // https://etherscan.io/tx/0x055c23e665428df16a5fc8b0c6d08b6ccc95f5a65d2ce5f68d7a68568152e19b
        // block 18633992
        uint256 fork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(fork);
        vm.rollFork(18_633_991);
        lendPool = ILendPool(BENDDAO_PROXY);
        vm.label(maycOwner, "maycOwner");
        vm.label(BENDDAO_PROXY, "BendDAO pool");
        vm.label(LEND_POOL_ADDRESS_PROVIDER, "LendPoolAddressProvider");
        vm.label(USDT, "USDT");
        vm.label(WETH, "WETH");
        vm.label(MAYC, "MAYC");
        userA = makeAddr("userA");
        lendPoolAddressesProvider = ILendPoolAddressesProvider(LEND_POOL_ADDRESS_PROVIDER);
        lendPoolLoan = ILendPoolLoan(lendPoolAddressesProvider.getLendPoolLoan());
        lendPool = ILendPool(lendPoolAddressesProvider.getLendPool());
        bNFTRegistry = IBNFTRegistry(lendPoolAddressesProvider.getBNFTRegistry());
        NFTOracleGetter = INFTOracleGetter(lendPoolAddressesProvider.getNFTOracle());
        (bMAYC, ) = bNFTRegistry.getBNFTAddresses(MAYC);
        vm.label(address(lendPoolLoan), "LendPoolLoan");
        vm.label(address(lendPool), "LendPool");
        vm.label(address(NFTOracleGetter), "NFTOracleGetter");
        vm.label(address(bNFTRegistry), "bNFTRegistry");
        vm.label(bMAYC, "bMAYC");
    }

    function test_BatchBorrow() public {
        vm.startPrank(maycOwner);

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory nftAssets = new address[](1);
        uint256[] memory nftTokenIds = new uint256[](1);
        assets[0] = WETH;
        uint _nftFloor = NFTOracleGetter.getAssetPrice(MAYC);
        amounts[0] = _nftFloor * 5000 / 10000; // max LTV: 50%
        nftAssets[0] = MAYC;
        uint _tokenId = 10306;
        nftTokenIds[0] = _tokenId;

        lendPool.batchBorrow(assets, amounts, nftAssets, nftTokenIds, maycOwner, 0);
        
        uint loanId = lendPoolLoan.getCollateralLoanId(MAYC, _tokenId);
        (address _reserve, uint _amount) = lendPoolLoan.getLoanReserveBorrowAmount(loanId);
        console2.log("_reserve: ", _reserve, " _amount: ", _amount);

        vm.stopPrank();
    }

    function testBatchBorrow_UserA() public {
        vm.startPrank(maycOwner);
        uint _tokenId = 10306;
        IERC721(MAYC).balanceOf(maycOwner);
        IERC721(MAYC).ownerOf(_tokenId);
        IERC721(MAYC).transferFrom(maycOwner, userA, _tokenId);
        vm.stopPrank();

        vm.startPrank(userA);
        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        address[] memory nftAssets = new address[](1);
        uint256[] memory nftTokenIds = new uint256[](1);
        assets[0] = WETH;
        uint _nftFloor = NFTOracleGetter.getAssetPrice(MAYC);
        amounts[0] = _nftFloor * 5000 / 10000; // max LTV: 50%
        nftAssets[0] = MAYC;
        nftTokenIds[0] = _tokenId;

        IERC721(MAYC).approve(address(lendPool), _tokenId);
        lendPool.batchBorrow(assets, amounts, nftAssets, nftTokenIds, userA, 0);

        uint loanId = lendPoolLoan.getCollateralLoanId(MAYC, _tokenId);
        (address _reserve, uint _amount) = lendPoolLoan.getLoanReserveBorrowAmount(loanId);
        console2.log("_reserve: ", _reserve, " _amount: ", _amount);

        vm.stopPrank();
    }

    function testRepay() public {
        testBatchBorrow_UserA();

        // vm.rollFork(block.number + 10); // borror APR > 0

        vm.startPrank(userA);
        uint _tokenId = 10306;
        uint _borrowAmount = IERC20(WETH).balanceOf(userA);

        uint _loanId = lendPoolLoan.getCollateralLoanId(MAYC, _tokenId);
        (address reserveAsset, uint debt) = lendPoolLoan.getLoanReserveBorrowAmount(_loanId);
        console2.log("_borrowAmount: ", _borrowAmount);
        console2.log("reserveAsset: ", reserveAsset);
        console2.log("debt: ", debt);

        deal(WETH, userA, debt);
        console2.log("diff: ", debt - _borrowAmount);
        IERC20(WETH).approve(address(lendPool), debt);
        IERC721(MAYC).ownerOf(_tokenId);
        lendPool.repay(MAYC, _tokenId, debt);
        (reserveAsset, debt) = lendPoolLoan.getLoanReserveBorrowAmount(_loanId);
        console2.log("reserveAsset: ", reserveAsset);
        console2.log("debt: ", debt);
        IERC721(MAYC).ownerOf(_tokenId);
        vm.stopPrank();
    }

    function testMultipleRepay() public {
        testBatchBorrow_UserA();

        vm.rollFork(block.number + 10);

        vm.startPrank(userA);
        uint _tokenId = 10306;
        uint _borrowAmount = IERC20(WETH).balanceOf(userA);

        uint _loanId = lendPoolLoan.getCollateralLoanId(MAYC, _tokenId);
        (address reserveAsset, uint debt) = lendPoolLoan.getLoanReserveBorrowAmount(_loanId);
        console2.log("_borrowAmount: ", _borrowAmount);
        console2.log("reserveAsset: ", reserveAsset);
        console2.log("debt: ", debt);

        deal(WETH, userA, debt + 1e18);
        console2.log("Diff of current debt and borrowAmount: ", debt - _borrowAmount);
        IERC20(WETH).approve(address(lendPool), _borrowAmount);
        IERC721(MAYC).ownerOf(_tokenId);

        // First
        lendPool.repay(MAYC, _tokenId, _borrowAmount);
        IERC721(MAYC).ownerOf(_tokenId);

        ( , debt) = lendPoolLoan.getLoanReserveBorrowAmount(_loanId);
        // Second
        IERC20(WETH).approve(address(lendPool), debt);
        lendPool.repay(MAYC, _tokenId, debt);
        IERC721(MAYC).ownerOf(_tokenId);

        vm.stopPrank();
    }
}
