// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {NFTLeverageStorageV1} from "./NFTLeverageStorageV1.sol";
import {Errors} from "../libraries/Errors.sol";
import {ILendingAdapter} from "../interfaces/ILendingAdapter.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "openzeppelin-contracts/contracts/interfaces/IERC721Receiver.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILendPool} from "../interfaces/benddao/ILendPool.sol";
import {IFragmentAdapter}  from "../interfaces/IFragmentAdapter.sol";
import {IPriceOracleAdapter} from "../interfaces/IPriceOracleAdapter.sol";

/**
 * @title NFTLeverageV1
 * @dev This contract implements the functionality for leveraging, deleveraging NFT positions and positions risk management.
 */
contract NFTLeverageV1 is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuard, NFTLeverageStorageV1, IERC721Receiver {
    function initializeV1(address _lendingAdapter, address _fragmentAdapter, address _priceOracleAdapter) external initializer {
        __Ownable_init(msg.sender);
        version = VERSION();
        _addLendingAdapter(_lendingAdapter);
        _addFragmentAdapter(_fragmentAdapter);
        _addPriceOracleAdapter(_priceOracleAdapter);
    }

    function VERSION() public pure returns (string memory) {
        return "v1";
    }

    /**
     * @dev Leverages the position by borrowing a loan amount based on the given LeverageParams.
     * @param _leverageParams The parameters for leveraging the position.
     */
    function leverage(LeverageParams memory _leverageParams) external onlyOwner onlyProxy nonReentrant returns(uint256) {
        require(_leverageParams.lendingIndex < lendingAdapters.length, Errors.LEND_INVALID_LENDING_ADAPTER_INDEX);
        ILendingAdapter lendingAdapter = ILendingAdapter(lendingAdapters[_leverageParams.lendingIndex]);
        require(lendingAdapter.isNftSupported(_leverageParams.collateralAsset), Errors.LEND_INVALID_NFT_ASSET_ADDRESS);
        require(lendingAdapter.isBorrowAssetSupported(_leverageParams.loanAsset), Errors.LEND_INVALID_LOAN_ASSET_ADDRESS);
        require(_leverageParams.maxBorrowRate == 0 || lendingAdapter.getBorrowAPR(_leverageParams.collateralAsset, _leverageParams.loanAsset) <= _leverageParams.maxBorrowRate, Errors.LEND_OVER_MAX_BORROW_RATE);
        uint floorPrice = lendingAdapter.getFloorPrice(_leverageParams.collateralAsset);
        require(floorPrice > 0, Errors.LEND_INVALID_FLOOR_PRICE);
        uint loanAmount = floorPrice * _leverageParams.targetLR / LR_BASE;
        uint balanceBefore = IERC20(_leverageParams.loanAsset).balanceOf(address(this));
        _borrow(
            _leverageParams.loanAsset,
            loanAmount,
            _leverageParams.collateralAsset,
            _leverageParams.collateralId,
            _leverageParams.lendingIndex
        );
        uint balanceAfter = IERC20(_leverageParams.loanAsset).balanceOf(address(this));
        require(balanceAfter - balanceBefore == loanAmount, Errors.LEND_INVALID_LOAN_AMOUNT);

        uint fragmentAmount = 0;
        if (_leverageParams.toFragment) {         
            require(IERC20(WETH).transfer(address(fragmentAdapters[_leverageParams.fragmentIndex]), loanAmount), Errors.ERC20_TRANSFER_FAILED);
            fragmentAmount = _exchange(_leverageParams.collateralAsset, WETH, loanAmount, _leverageParams.fragmentIndex);
        }

        leveragedPositions.push(LeveragedPosition({
            lendingIndex: _leverageParams.lendingIndex,
            loanAmount: loanAmount,
            loanAsset: _leverageParams.loanAsset,
            collateralAsset: _leverageParams.collateralAsset,
            collateralId: _leverageParams.collateralId,
            fragmentIndex: _leverageParams.fragmentIndex,
            fragmentAsset: IFragmentAdapter(fragmentAdapters[_leverageParams.fragmentIndex]).getFragmentAsset(_leverageParams.collateralAsset),
            fragmentAmount: fragmentAmount
        }));

        return leveragedPositions.length - 1;
    }

    /**
     * @dev Deleverages the leveraged position.
     * @param _deleverageParams The parameters for deleveraging.
     */
    function deleverage(DeleverageParams memory _deleverageParams) external onlyOwner onlyProxy nonReentrant {
        require(_deleverageParams.positionIndex < leveragedPositions.length, Errors.LEND_INVALID_POSITION_INDEX);
        require(_deleverageParams.deRatio > 0, Errors.LEND_INVALID_RATIO);
        
        // Exchange fragment
        LeveragedPosition storage position = leveragedPositions[_deleverageParams.positionIndex];
        LeveragedPosition memory positionCache = position;
        if (_deleverageParams.exchangeFragment) {
            if (positionCache.fragmentAmount > 0 && IERC20(positionCache.fragmentAsset).balanceOf(address(this)) >= positionCache.fragmentAmount) {
                require(IERC20(positionCache.fragmentAsset).transfer(address(fragmentAdapters[positionCache.fragmentIndex]), positionCache.fragmentAmount), Errors.ERC20_TRANSFER_FAILED);
                _exchange(positionCache.collateralAsset, positionCache.collateralAsset, positionCache.fragmentAmount, positionCache.fragmentIndex);
                position.fragmentAmount = 0;
            }
        }
        ILendingAdapter lendingAdapter = ILendingAdapter(lendingAdapters[positionCache.lendingIndex]);
        uint balanceBefore = IERC20(positionCache.loanAsset).balanceOf(address(this));

        // Calculate repay amount
        uint repayAmount;
        uint currentLTV = lendingAdapter.getLTV(positionCache.collateralAsset, positionCache.collateralId);
        uint debtBefore = lendingAdapter.getDebt(positionCache.collateralAsset, positionCache.collateralId);
        bool fullyRepay;
        if (currentLTV > _deleverageParams.deRatio) {
            repayAmount = debtBefore * _deleverageParams.deRatio / currentLTV;
            fullyRepay = false;
        } else {
            repayAmount = debtBefore;
            fullyRepay = true;
            // Remove position
            if (_deleverageParams.positionIndex < leveragedPositions.length - 1) {
                position = leveragedPositions[leveragedPositions.length - 1];
            }
            leveragedPositions.pop();
        }
        require(_deleverageParams.maxRepayAmount == 0 || repayAmount < _deleverageParams.maxRepayAmount, Errors.LEND_OVER_MAX_REPAY_AMOUNT);
        
        // Repay
        uint extraRepayAmount = 0;
        if (balanceBefore < repayAmount) {
            extraRepayAmount = repayAmount - balanceBefore;
            require(IERC20(positionCache.loanAsset).transferFrom(msg.sender, address(this), extraRepayAmount), Errors.ERC20_TRANSFER_FAILED);
        }
        (bool success, ) = address(lendingAdapter).delegatecall(abi.encodeWithSignature("repay(address,uint256,uint256)", positionCache.collateralAsset, positionCache.collateralId, repayAmount));
        require(success, Errors.LEND_REPAY_FAILED);
        uint balanceAfter = IERC20(positionCache.loanAsset).balanceOf(address(this));
        require((balanceBefore + extraRepayAmount - balanceAfter) == repayAmount, Errors.LEND_INCORRECT_REPAY_AMOUNT);

        // Fully repaid
        if (fullyRepay) {
            uint _collateralId = positionCache.collateralId;
            address _collateralAsset = positionCache.collateralAsset;
            // Return collateral
            IERC721(_collateralAsset).safeTransferFrom(address(this), msg.sender, _collateralId);
        } else {
            position.loanAmount = lendingAdapter.getDebt(positionCache.collateralAsset, positionCache.collateralId);
        }
    }

    /**
     * @dev Withdraws ERC20 tokens from the contract to a specified address.
     * Only the contract owner can call this function.
     * @param _to The address to which the tokens will be withdrawn.
     * @param _asset The address of the ERC20 token to be withdrawn.
     * @param _amount The amount of tokens to be withdrawn.
     */
    function withdrawTo(address _to, address _asset, uint256 _amount) external onlyOwner onlyProxy nonReentrant {
        require(_to != address(0), Errors.LEND_INVALID_WITHDRAW_ADDRESS);
        require(_asset != address(0), Errors.LEND_INVALID_WITHDRAW_ASSET_ADDRESS);
        require(_amount > 0, Errors.LEND_INVALID_WITHDRAW_AMOUNT);

        require(IERC20(_asset).transfer(_to, _amount), Errors.ERC20_TRANSFER_FAILED);
    }

    /**
     * @dev Withdraws ERC721 tokens from the contract to a specified address.
     * Only the contract owner can call this function.
     * @param _to The address to which the tokens will be withdrawn.
     * @param _asset The address of the ERC721 token to be withdrawn.
     * @param _tokenId The ID of the token to be withdrawn.
     */
    function withdrawNftTo(address _to, address _asset, uint256 _tokenId) external onlyOwner onlyProxy nonReentrant {
        require(_to != address(0), Errors.LEND_INVALID_WITHDRAW_ADDRESS);
        require(_asset != address(0), Errors.LEND_INVALID_WITHDRAW_ASSET_ADDRESS);

        IERC721(_asset).safeTransferFrom(address(this), _to, _tokenId);
    }

    /**
     * @dev Withdraws a specified amount of ETH to the given address.
     * @param _to The address to which the ETH will be withdrawn.
     * @param _amount The amount of ETH to be withdrawn.
     */
    function withdrawEthTo(address payable _to, uint256 _amount) external onlyOwner onlyProxy nonReentrant {
        require(_to != address(0), Errors.LEND_INVALID_WITHDRAW_ADDRESS);
        require(_amount > 0, Errors.LEND_INVALID_WITHDRAW_AMOUNT);

        _to.transfer(_amount);
    }

    /**
     * @dev Adds a lending adapter contract address to the NFTLeverageV1 contract.
     * Only the contract owner and the proxy contract can call this function.
     * @param _lendingAdapter The address of the lending adapter contract to be added.
     */
    function addLendingAdapter(address _lendingAdapter) external onlyOwner onlyProxy {
        _addLendingAdapter(_lendingAdapter);
    }

    /**
     * @dev Adds a fragment adapter contract address to the NFTLeverageV1 contract.
     * Only the contract owner and the proxy contract can call this function.
     * @param _fragmentAdapter The address of the fragment adapter contract to be added.
     */
    function addFragmentAdapter(address _fragmentAdapter) external onlyOwner onlyProxy {
        _addFragmentAdapter(_fragmentAdapter);
    }

    /**
     * @dev Retrieves the leveraged position at the specified index.
     * @param _positionIndex The index of the leveraged position.
     * @return The LeveragedPosition struct representing the leveraged position.
     */
    function getLeveragePosition(uint256 _positionIndex) external view onlyOwner onlyProxy returns (LeveragedPosition memory) {
        require(_positionIndex < leveragedPositions.length, Errors.LEND_INVALID_POSITION_INDEX);
        return leveragedPositions[_positionIndex];
    }

    /**
     * @dev Retrieves the loan-to-value (LTV) ratio for the leveraged position at the specified index.
     * @param _positionIndex The index of the leveraged position.
     * @return The LTV ratio as a uint256 value.
     */
    function getLTV(uint256 _positionIndex) external onlyOwner onlyProxy returns (uint256) {
        require(_positionIndex < leveragedPositions.length, Errors.LEND_INVALID_POSITION_INDEX);
        LeveragedPosition memory position = leveragedPositions[_positionIndex];
        return ILendingAdapter(lendingAdapters[position.lendingIndex]).getLTV(position.collateralAsset, position.collateralId);
    }

    /**
     * @dev Retrieves the collateral value for the leveraged position at the specified index.
     * @param _positionIndex The index of the leveraged position.
     * @return The collateral value as a uint256 value.
     */
    function getCollateralValue(uint256 _positionIndex) external onlyOwner onlyProxy returns (uint256) {
        require(_positionIndex < leveragedPositions.length, Errors.LEND_INVALID_POSITION_INDEX);
        LeveragedPosition memory position = leveragedPositions[_positionIndex];
        return ILendingAdapter(lendingAdapters[position.lendingIndex]).getCollateralValue(position.collateralAsset, position.collateralId);
    }

    /**
     * @dev Retrieves the debt amount for the leveraged position at the specified index.
     * @param _positionIndex The index of the leveraged position.
     * @return The debt amount as a uint256 value.
     */
    function getDebt(uint256 _positionIndex) external onlyOwner onlyProxy returns (uint256) {
        require(_positionIndex < leveragedPositions.length, Errors.LEND_INVALID_POSITION_INDEX);
        LeveragedPosition memory position = leveragedPositions[_positionIndex];
        return ILendingAdapter(lendingAdapters[position.lendingIndex]).getDebt(position.collateralAsset, position.collateralId);
    }

    /**
     * @dev Retrieves the health factor for the leveraged position at the specified index.
     * @param _positionIndex The index of the leveraged position.
     * @return The health factor as a uint256 value.
     */
    function getHealthFactor(uint256 _positionIndex) external onlyOwner onlyProxy returns (uint256) {
        require(_positionIndex < leveragedPositions.length, Errors.LEND_INVALID_POSITION_INDEX);
        LeveragedPosition memory position = leveragedPositions[_positionIndex];
        return ILendingAdapter(lendingAdapters[position.lendingIndex]).getHealthFactor(position.collateralAsset, position.collateralId);
    }

    /**
     * @dev Retrieves the annual percentage rate (APR) for borrowing the specified loan asset against the collateral asset.
     * @param _collateralAsset The address of the collateral asset.
     * @param _loanAsset The address of the loan asset.
     * @param _lendingIndex The index of the lending adapter.
     * @return The APR as a uint256 value.
     */
    function getBorrowAPR(address _collateralAsset, address _loanAsset, uint256 _lendingIndex) external view onlyOwner onlyProxy returns (uint256) {
        require(_lendingIndex < lendingAdapters.length, Errors.LEND_INVALID_LENDING_ADAPTER_INDEX);
        require(_collateralAsset != address(0), Errors.LEND_INVALID_COLLATERAL_ASSET_ADDRESS);
        require(_loanAsset != address(0), Errors.LEND_INVALID_LOAN_ASSET_ADDRESS);
        return ILendingAdapter(lendingAdapters[_lendingIndex]).getBorrowAPR(_collateralAsset, _loanAsset);
    }

    /**
     * @dev Retrieves the floor price of the specified NFT asset.
     * @param _asset The address of the NFT asset.
     * @param _lendingIndex The index of the lending adapter.
     * @return The floor price as a uint256 value.
     */
    function getNftPrice(address _asset, uint256 _lendingIndex) external onlyOwner onlyProxy returns (uint256) {
        require(_lendingIndex < lendingAdapters.length, Errors.LEND_INVALID_LENDING_ADAPTER_INDEX);
        require(_asset != address(0), Errors.LEND_INVALID_COLLATERAL_ASSET_ADDRESS);
        return ILendingAdapter(lendingAdapters[_lendingIndex]).getFloorPrice(_asset);
    }

    /**
     * @dev Retrieves the price of the specified fragment asset.
     * @param _asset The address of the fragment asset.
     * @param _priceOracleIndex The index of the price oracle adapter.
     * @return The price as a uint256 value.
     */
    function getFragmentPrice(address _asset, uint256 _priceOracleIndex) external onlyOwner onlyProxy returns (uint256) {
        require(_priceOracleIndex < priceOracleAdapters.length, Errors.ORACLE_INVALID_PRICE_ORACLE_ADAPTER_INDEX);
        require(_asset != address(0), Errors.FRAG_INVALID_NFT_ASSET_ADDRESS);
        return IPriceOracleAdapter(priceOracleAdapters[_priceOracleIndex]).getPrice(_asset, WETH);
    }

    /**
     * @dev Retrieves the maximum loan-to-value (LTV) ratio for the specified collateral asset.
     * @param _asset The address of the collateral asset.
     * @param _lendingIndex The index of the lending adapter.
     * @return The maximum LTV ratio as a uint256 value.
     */
    function getMaxLTV(address _asset, uint256 _lendingIndex) external view onlyOwner onlyProxy returns (uint256) {
        require(_lendingIndex < lendingAdapters.length, Errors.LEND_INVALID_LENDING_ADAPTER_INDEX);
        require(_asset != address(0), Errors.LEND_INVALID_COLLATERAL_ASSET_ADDRESS);
        return ILendingAdapter(lendingAdapters[_lendingIndex]).getMaxLTV(_asset);
    }

    /**
     * @dev Retrieves the address of the fragment asset associated with the specified NFT asset.
     * @param _asset The address of the NFT asset.
     * @param _fragmentIndex The index of the fragment adapter.
     * @return The address of the fragment asset.
     */
    function getFragmentAsset(address _asset, uint256 _fragmentIndex) external view onlyOwner onlyProxy returns (address) {
        require(_fragmentIndex < fragmentAdapters.length, Errors.FRAG_INVALID_FRAGMENT_ADAPTER_INDEX);
        require(_asset != address(0), Errors.FRAG_INVALID_NFT_ASSET_ADDRESS);
        return IFragmentAdapter(fragmentAdapters[_fragmentIndex]).getFragmentAsset(_asset);
    }

    /**
     * @dev Returns the total number of leveraged positions.
     * @return The total number of leveraged positions.
     */
    function totalLeveragedPositions() external view onlyOwner onlyProxy returns (uint256) {
        return leveragedPositions.length;
    }

    /**
     * @dev Function to handle the receipt of an ERC721 token.
     * @param _operator The address which called the `safeTransferFrom` function.
     * @param _from The address which previously owned the token.
     * @param _tokenId The token ID being transferred.
     * @param _data Additional data with no specified format.
     * @return A bytes4 value representing the ERC721 receiver function signature.
     */
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _borrow(
        address _loanAsset,
        uint256 _loanAmount,
        address _collateralAsset,
        uint256 _collateralId,
        uint8 _lendingIndex
    ) internal {
        require(_loanAmount > 0, Errors.LEND_INVALID_LOAN_AMOUNT);
        require(_loanAsset != address(0), Errors.LEND_INVALID_LOAN_ASSET_ADDRESS);
        require(_collateralAsset != address(0), Errors.LEND_INVALID_COLLATERAL_ASSET_ADDRESS);
        require(_lendingIndex < lendingAdapters.length, Errors.LEND_INVALID_LENDING_ADAPTER_INDEX);

        ILendingAdapter lendingAdapter = ILendingAdapter(lendingAdapters[_lendingIndex]);
        IERC721(_collateralAsset).transferFrom(msg.sender, address(this), _collateralId);
        (bool success, ) = address(lendingAdapter).delegatecall(abi.encodeWithSignature("borrow(address,uint256,address,uint256)", _collateralAsset, _collateralId, _loanAsset, _loanAmount));
        require(success, Errors.LEND_BORROW_FAILED);
    }

    function _exchange(
        address _nftAsset,
        address _fromAsset,
        uint256 _fromAmount,
        uint8 _fragmentIndex
    ) internal returns(uint256) {
        require(_nftAsset != address(0), Errors.FRAG_INVALID_NFT_ASSET_ADDRESS);
        require(_fromAsset != address(0), Errors.FRAG_INVALID_FROM_ASSET_ADDRESS);
        require(_fromAmount > 0, Errors.FRAG_INVALID_FROM_AMOUNT);
        require(_fragmentIndex < fragmentAdapters.length, Errors.FRAG_INVALID_FRAGMENT_ADAPTER_INDEX);

        address fragmentAsset = IFragmentAdapter(fragmentAdapters[_fragmentIndex]).getFragmentAsset(_nftAsset);
        require(fragmentAsset != address(0), Errors.FRAG_INVALID_FRAGMENT_ASSET_ADDRESS);
        uint256 tokenOutAmount;
        if (_fromAsset == _nftAsset) {
            tokenOutAmount = IFragmentAdapter(fragmentAdapters[_fragmentIndex]).swapFromFragment(_fromAmount, _nftAsset);
            require(tokenOutAmount > 0, Errors.FRAG_INVALID_FRAGMENT_AMOUNT);
        } else {
            tokenOutAmount = IFragmentAdapter(fragmentAdapters[_fragmentIndex]).swapToFragment(_fromAsset, _fromAmount, _nftAsset);
            require(tokenOutAmount > 0, Errors.FRAG_INVALID_FRAGMENT_AMOUNT);
        }

        return tokenOutAmount;
    }
    
    function _addLendingAdapter(address _lendingAdapter) internal {
        require(_lendingAdapter != address(0), Errors.LEND_INVALID_LENDING_ADAPTER_ADDRESS);
        ILendingAdapter adapter = ILendingAdapter(_lendingAdapter);
        lendingAdapters.push(_lendingAdapter);
    }

    function _addFragmentAdapter(address _fragmentAdapter) internal {
        require(_fragmentAdapter != address(0), Errors.FRAG_INVALID_FRAGMENT_ADAPTER_ADDRESS);

        IFragmentAdapter adapter = IFragmentAdapter(_fragmentAdapter);
        fragmentAdapters.push(_fragmentAdapter);
    }

    function _addPriceOracleAdapter(address _priceOracleAdapter) internal {
        require(_priceOracleAdapter != address(0), Errors.ORACLE_INVALID_PRICE_ORACLE_ADAPTER_ADDRESS);

        IPriceOracleAdapter adapter = IPriceOracleAdapter(_priceOracleAdapter);
        priceOracleAdapters.push(_priceOracleAdapter);
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner onlyProxy {
        require(newImplementation != address(0), Errors.UG_INVALID_IMPLEMENTATION_ADDRESS);
    }
}
