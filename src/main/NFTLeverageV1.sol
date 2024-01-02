// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {NFTLeverageStorageV1} from "./NFTLeverageStorageV1.sol";
import {Errors} from "../libraries/Errors.sol";
import {ILendingAdapter} from "../interfaces/ILendingAdapter.sol";
import {IERC721} from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "openzeppelin-contracts/contracts/interfaces/IERC721Receiver.sol";
import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {ILendPool} from "../interfaces/benddao/ILendPool.sol";
import {IFragmentAdapter}  from "../interfaces/IFragmentAdapter.sol";

contract NFTLeverageV1 is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuard, NFTLeverageStorageV1, IERC721Receiver {
    function initializeV1(address _lendingAdapter, address _fragmentAdapter) public initializer {
        __Ownable_init(msg.sender);
        version = VERSION();
        _addLendingAdapter(_lendingAdapter);
        _addFragmentAdapter(_fragmentAdapter);
    }

    function createLeverage(LeverageParams memory leverageParams) public onlyProxy nonReentrant {
        address lendingAdapter = lendingAdapters[leverageParams.lendingIndex];
        uint256 floorPrice = ILendingAdapter(lendingAdapter).getFloorPrice(leverageParams.collateralAsset);
        require(floorPrice > 0, Errors.LEND_INVALID_FLOOR_PRICE);
        uint loanAmount = floorPrice * leverageParams.targetLR / LR_BASE;
        uint balanceBefore = IERC20(leverageParams.loanAsset).balanceOf(address(this));
        _borrow(
            leverageParams.loanAsset,
            loanAmount,
            leverageParams.collateralAsset,
            leverageParams.collateralId,
            leverageParams.lendingIndex,
            leverageParams.maxBorrowRate
        );
        uint balanceAfter = IERC20(leverageParams.loanAsset).balanceOf(address(this));
        require(balanceAfter - balanceBefore == loanAmount, Errors.LEND_INVALID_LOAN_AMOUNT);

        uint _fragmentAmount;
        if (leverageParams.toFragment) {
            IERC20(WETH).transfer(address(fragmentAdapters[leverageParams.fragmentIndex]), loanAmount);
            _fragmentAmount = _exchange(leverageParams.collateralAsset, WETH, loanAmount, leverageParams.fragmentIndex);
        }

        leveragedPositions.push(LeveragedPosition({
            lendingIndex: leverageParams.lendingIndex,
            loanAmount: loanAmount,
            loanAsset: leverageParams.loanAsset,
            collateralAsset: leverageParams.collateralAsset,
            collateralId: leverageParams.collateralId,
            fragmentIndex: leverageParams.fragmentIndex,
            fragmentAsset: IFragmentAdapter(fragmentAdapters[leverageParams.fragmentIndex]).getFragmentAsset(leverageParams.collateralAsset),
            fragmentAmount: _fragmentAmount
        }));
    }

    function removeLeverage(uint256 _positionIndex) public onlyProxy nonReentrant {
        require(_positionIndex < leveragedPositions.length, Errors.LEND_INVALID_POSITION_INDEX);
        LeveragedPosition memory position = leveragedPositions[_positionIndex];
        ILendingAdapter lendingAdapter = ILendingAdapter(lendingAdapters[position.lendingIndex]);

        if (position.fragmentAmount > 0) {
            IERC20(position.fragmentAsset).transfer(address(fragmentAdapters[position.fragmentIndex]), position.fragmentAmount);
            _exchange(position.collateralAsset, position.collateralAsset, position.fragmentAmount, position.fragmentIndex);
        }

        uint balanceBefore = IERC20(position.loanAsset).balanceOf(address(this)); //TODO: remove
        uint256 repayAmount = lendingAdapter.getDebt(position.collateralAsset, position.collateralId);
        if (balanceBefore < repayAmount) {
            IERC20(position.loanAsset).transferFrom(msg.sender, address(this), repayAmount - balanceBefore);
        }

        (bool success, ) = address(lendingAdapter).delegatecall(abi.encodeWithSignature("repay(address,uint256,uint256)", position.collateralAsset, position.collateralId, repayAmount));
        require(success);

        leveragedPositions[_positionIndex] = leveragedPositions[leveragedPositions.length - 1];
        leveragedPositions.pop();

        IERC721(position.collateralAsset).transferFrom(address(this), msg.sender, position.collateralId);
    }

    function withdrawTo(address _to, address _asset, uint256 _amount) public onlyOwner nonReentrant {
        require(_to != address(0), Errors.LEND_INVALID_WITHDRAW_ADDRESS);
        require(_asset != address(0), Errors.LEND_INVALID_WITHDRAW_ASSET_ADDRESS);
        require(_amount > 0, Errors.LEND_INVALID_WITHDRAW_AMOUNT);

        IERC20(_asset).transfer(_to, _amount);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _borrow(
        address _loanAsset,
        uint256 _loanAmount,
        address _collateralAsset,
        uint256 _collateralId,
        uint8 _lendingIndex,
        uint256 _maxBorrowRate
    ) internal {
        require(_loanAmount > 0, Errors.LEND_INVALID_LOAN_AMOUNT);
        require(_loanAsset != address(0), Errors.LEND_INVALID_LOAN_ASSET_ADDRESS);
        require(_collateralAsset != address(0), Errors.LEND_INVALID_COLLATERAL_ASSET_ADDRESS);
        require(_lendingIndex < lendingAdapters.length, Errors.LEND_INVALID_LENDING_ADAPTER_INDEX);

        ILendingAdapter lendingAdapter = ILendingAdapter(lendingAdapters[_lendingIndex]);
        IERC721(_collateralAsset).transferFrom(msg.sender, address(this), _collateralId);
        (bool success, ) = address(lendingAdapter).delegatecall(abi.encodeWithSignature("borrow(address,uint256,address,uint256,uint256)", _collateralAsset, _collateralId, _loanAsset, _loanAmount, _maxBorrowRate));
        require(success);
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

    function _removeLendingAdapter(uint8 _lendingIndex) internal {
        require(_lendingIndex < lendingAdapters.length, Errors.LEND_INVALID_LENDING_ADAPTER_INDEX);

        lendingAdapters[_lendingIndex] = lendingAdapters[lendingAdapters.length - 1];
        lendingAdapters.pop();
    }

    function _addFragmentAdapter(address _fragmentAdapter) internal {
        require(_fragmentAdapter != address(0), Errors.FRAG_INVALID_FRAGMENT_ADAPTER_ADDRESS);

        IFragmentAdapter adapter = IFragmentAdapter(_fragmentAdapter);
        fragmentAdapters.push(_fragmentAdapter);
    }

    function _removeFragmentAdapter(uint8 _fragmentIndex) internal {
        require(_fragmentIndex < fragmentAdapters.length, Errors.FRAG_INVALID_FRAGMENT_ADAPTER_INDEX);

        fragmentAdapters[_fragmentIndex] = fragmentAdapters[fragmentAdapters.length - 1];
        fragmentAdapters.pop();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner onlyProxy {
        require(newImplementation != address(0), Errors.UG_INVALID_IMPLEMENTATION_ADDRESS);
    }

    function VERSION() public pure returns (string memory) {
        return "v1";
    }
}
