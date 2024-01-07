// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IFragmentAdapter.sol";
import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract FloorProtocolAdapter is IFragmentAdapter, Ownable, ReentrancyGuard  {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant BAYC = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
    address public constant microBAYC = 0x1e610De0D7ACfa1d820024948a91D96C5c9CE6B9;
    address public constant MAYC = 0x60E4d786628Fea6478F785A6d7e704777c86a7c6;
    address public constant microMAYC = 0x359108Ca299ca693502Ef217e2109aD02Aa4277C;
    address public constant AZUKI = 0xED5AF388653567Af2F388E6224dC7C4b3241C544;
    address public constant microAZUKI = 0x3acFc40a19520D97648eB7c0891e747b7F2B0283;

    struct FragmentInfo {
        address fragmentAsset;
        address v3Pool;
        uint24 fee;
    }

    mapping(address => FragmentInfo) public fragmentAssets;

    constructor() Ownable(msg.sender) {
        _initFragmentAssets();
    }

    /**
     * @dev Returns the fragment asset associated with the given NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @return The address of the fragment asset.
     */
    function getFragmentAsset(address _nftAsset) external view override returns(address) {
        require(_nftAsset != address(0), "FloorProtocolAdapter: invalid nft asset");
        return fragmentAssets[_nftAsset].fragmentAsset;
    }

    function swapToFragment(address _tokenIn, uint256 _amountIn, address _nftAsset) external override nonReentrant returns(uint256) {
        require(_tokenIn != address(0), "FloorProtocolAdapter: invalid token in");
        require(_amountIn > 0, "FloorProtocolAdapter: invalid amount in");
        require(_nftAsset != address(0), "FloorProtocolAdapter: invalid nft asset");
        IERC20(_tokenIn).approve(UNISWAP_V3_ROUTER, _amountIn);
        uint amountOut = ISwapRouter(UNISWAP_V3_ROUTER).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: fragmentAssets[_nftAsset].fragmentAsset,
                fee: fragmentAssets[_nftAsset].fee,
                recipient: msg.sender,
                deadline: block.timestamp + 15,
                amountIn: _amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        return amountOut;
    }

    function swapFromFragment(uint256 _amountIn, address _nftAsset) external nonReentrant returns(uint256) {
        require(_amountIn > 0, "FloorProtocolAdapter: invalid amount in");
        require(_nftAsset != address(0), "FloorProtocolAdapter: invalid nft asset");
        IERC20(fragmentAssets[_nftAsset].fragmentAsset).approve(UNISWAP_V3_ROUTER, _amountIn);
        uint amountOut = ISwapRouter(UNISWAP_V3_ROUTER).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: fragmentAssets[_nftAsset].fragmentAsset,
                tokenOut: WETH,
                fee: fragmentAssets[_nftAsset].fee,
                recipient: msg.sender,
                deadline: block.timestamp + 15,
                amountIn: _amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        return amountOut;
    }

    /**
     * @dev Adds a fragment asset to the Floor Protocol adapter.
     * @param _nftAsset The address of the NFT asset.
     * @param _fragmentAsset The address of the fragment asset.
     * @param _v3Pool The address of the V3 pool.
     * @param _fee The fee for the transaction.
     */
    function addFragmentAsset(address _nftAsset, address _fragmentAsset, address _v3Pool, uint24 _fee) external onlyOwner {
        _setFragmentAsset(_nftAsset, _fragmentAsset, _v3Pool, _fee);
    }

    function withdrawEth() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function withdraw(address _asset) public onlyOwner {
        require(IERC20(_asset).transfer(owner(), IERC20(_asset).balanceOf(address(this))), "FloorProtocolAdapter: withdraw failed");
    }

    function _initFragmentAssets() internal {
        _setFragmentAsset(BAYC, microBAYC, 0xe72377ae353Edc1d07f6c0be34969a481D030D19, 3000);
        _setFragmentAsset(MAYC, microMAYC, 0x3f1004641A08ECf7f962DA59E60adEF1E9A241F6, 3000);
        _setFragmentAsset(AZUKI, microAZUKI, 0xB17015D33C97A2cacA73be2a8669076a333FD43d, 3000);
    }

    function _setFragmentAsset(address _nftAsset, address _fragmentAsset, address _v3Pool, uint24 _fee) internal {
        require(_nftAsset != address(0), "FloorProtocolAdapter: invalid nft asset");
        require(_fragmentAsset != address(0), "FloorProtocolAdapter: invalid fragment asset");
        require(_v3Pool != address(0), "FloorProtocolAdapter: invalid v3 pool");
        require(_fee > 0, "FloorProtocolAdapter: invalid fee");
        fragmentAssets[_nftAsset] = FragmentInfo(_fragmentAsset, _v3Pool, _fee);
    }
}