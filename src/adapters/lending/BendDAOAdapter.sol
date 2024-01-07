// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/ILendingAdapter.sol";
import {ILendPool} from "../../interfaces/benddao/ILendPool.sol";
import {ILendPoolAddressesProvider} from "../../interfaces/benddao/ILendPoolAddressesProvider.sol";
import {ILendPoolLoan} from "../../interfaces/benddao/ILendPoolLoan.sol";
import {INFTOracleGetter} from "../../interfaces/benddao/INFTOracleGetter.sol";
import {IBNFTRegistry} from "../../interfaces/benddao/IBNFTRegistry.sol";
import {IBNFT} from "../../interfaces/benddao/IBNFT.sol";
import {DataTypes} from "../../interfaces/benddao/DataTypes.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BendDAOAdapter
 * @dev This contract implements the ILendingAdapter interface and serves as an adapter for interacting with the BendDAO lending protocol.
 */

contract BendDAOAdapter is ILendingAdapter, Ownable, ReentrancyGuard {
    address public constant LEND_POOL_ADDRESS_PROVIDER = 0x24451F47CaF13B24f4b5034e1dF6c0E401ec0e46;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor() Ownable(msg.sender) {

    }

    /**
     * @dev Allows the caller to borrow a specified amount of a borrow asset by providing an NFT as collateral.
     * @param _nftAsset The address of the NFT asset used as collateral.
     * @param _tokenId The ID of the NFT token used as collateral.
     * @param _borrowAsset The address of the asset to be borrowed.
     * @param _borrowAmount The amount of the borrow asset to be borrowed.
     */
    function borrow(address _nftAsset, uint _tokenId, address _borrowAsset, uint _borrowAmount) external override nonReentrant {
        IERC721(_nftAsset).approve(address(LendPool()), _tokenId);
        LendPool().borrow(_borrowAsset, _borrowAmount, _nftAsset, _tokenId, address(this), 0);
    }

    /**
     * @dev Repays a specified amount of a loan for a given NFT asset and token ID.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The ID of the NFT token.
     * @param _repayAmount The amount to be repaid.
     */
    function repay(address _nftAsset, uint _tokenId, uint _repayAmount) external override nonReentrant {
        IERC20(WETH).approve(address(LendPool()), _repayAmount);
        LendPool().repay(_nftAsset, _tokenId, _repayAmount);
    }

    /**
     * @dev Checks if a specific NFT asset is supported by the lending protocol.
     * @param _nftAsset The address of the NFT asset.
     * @return A boolean indicating whether the NFT asset is supported.
     */
    function isNftSupported(address _nftAsset) external view override returns(bool) {
        address[] memory _nftAssets = LendPool().getNftsList();
        for (uint i = 0; i < _nftAssets.length;) {
            if (_nftAssets[i] == _nftAsset) {
                return true;
            }
            unchecked {
                i++;
            }
        }
    }

    /**
     * @dev Checks if a specific borrow asset is supported by the lending protocol.
     * @param _borrowAsset The address of the NFT asset.
     * @return A boolean indicating whether the borrow asset is supported.
     */
    function isBorrowAssetSupported(address _borrowAsset) external view override returns(bool) {
        address[] memory _borrowAssets = LendPool().getReservesList();
        for (uint i = 0; i < _borrowAssets.length;) {
            if (_borrowAssets[i] == _borrowAsset) {
                return true;
            }
            unchecked {
                i++;
            }
        }
    }

    /**
     * @dev Retrieves the floor price of an NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @return The floor price of the NFT asset.
     */
    function getFloorPrice(address _nftAsset) external view override returns(uint256) {
        return NFTOracleGetter().getAssetPrice(_nftAsset);
    }

    /**
     * @dev Retrieves the total collateral value of an NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The ID of the NFT token.
     * @return The total collateral value of the NFT asset.
     */
    function getCollateralValue(address _nftAsset, uint _tokenId) external override returns(uint256) {
        ( , , uint _totalCollateral, , , ) = LendPool().getNftDebtData(_nftAsset, _tokenId); 

        return _totalCollateral;
    }

    /**
     * @dev Returns the debt of a specific NFT asset and token ID.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The token ID of the NFT.
     * @return The debt of the NFT.
     */
    function getDebt(address _nftAsset, uint _tokenId) external override returns(uint256) {
        ( , , , uint _totalDebt, , ) = LendPool().getNftDebtData(_nftAsset, _tokenId); 

        return _totalDebt;
    }

    /**
     * @dev Returns the annual percentage rate (APR) for borrowing a specific asset against an NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @param _borrowAsset The address of the asset to be borrowed.
     * @return The borrow APR as a uint256 value. 0 if the borrow asset is not supported.
     */
    function getBorrowAPR(address _nftAsset, address _borrowAsset) external view override returns(uint256) {
        if (this.isNftSupported(_nftAsset)) {
            DataTypes.ReserveData memory _reserveData = LendPool().getReserveData(_borrowAsset);
            return uint256(_reserveData.currentVariableBorrowRate);
        } else {
            return 0;
        }
    }

    /**
     * @dev Returns the loan-to-value (LTV) ratio of a specific NFT asset and token ID.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The token ID of the NFT.
     * @return The LTV ratio of the NFT. 0 if the NFT asset is not supported.
     */
    function getLTV(address _nftAsset, uint _tokenId) external view override returns(uint256) {
        ( , , uint _totalCollateral, uint _totalDebt, , ) = LendPool().getNftDebtData(_nftAsset, _tokenId);
        uint ltv;
        if (_totalCollateral == 0) {
            ltv = 0;
        } else {
            ltv = _totalDebt * 10000 / _totalCollateral;
        }

        return ltv;
    }

    /**
     * @dev Returns the maximum loan-to-value (LTV) ratio of a specific NFT asset.
     * @param _nftAsset The address of the NFT asset.
     * @return The maximum LTV ratio of the NFT asset.
     */
    function getMaxLTV(address _nftAsset) external view override returns(uint256) {
        ( , , , , uint maxLTV, , ) = LendPool().getNftCollateralData(_nftAsset, WETH);

        return maxLTV;
    }

    /**
     * @dev Returns the health factor of a specific NFT asset and token ID.
     * @param _nftAsset The address of the NFT asset.
     * @param _tokenId The token ID of the NFT.
     * @return The health factor of the NFT.
     */
    function getHealthFactor(address _nftAsset, uint _tokenId) external view override returns(uint256) {
        ( , , , , , uint healthFactor) = LendPool().getNftDebtData(_nftAsset, _tokenId);

        return healthFactor;
    }

    function LendPoolAddressProvider() public view returns (ILendPoolAddressesProvider) {
        return ILendPoolAddressesProvider(LEND_POOL_ADDRESS_PROVIDER);
    }

    function LendPool() public view returns (ILendPool) {
        return ILendPool(LendPoolAddressProvider().getLendPool());
    }

    function LendPoolLoan() public view returns (ILendPoolLoan) {
        return ILendPoolLoan(LendPoolAddressProvider().getLendPoolLoan());
    }

    function NFTOracleGetter() public view returns (INFTOracleGetter) {
        return INFTOracleGetter(LendPoolAddressProvider().getNFTOracle());
    }

    function BNFTRegistry() public view returns (IBNFTRegistry) {
        return IBNFTRegistry(LendPoolAddressProvider().getBNFTRegistry());
    }

    function withdrawEth() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function withdraw(address _asset) public onlyOwner {
        IERC20(_asset).transfer(owner(), IERC20(_asset).balanceOf(address(this)));
    }
}