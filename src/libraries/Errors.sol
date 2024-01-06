// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Errors library
 */
library Errors {
  // upgrade errors
  string public constant UG_INVALID_IMPLEMENTATION_ADDRESS = "001";
  string public constant UG_NEW_IMPLEMENTAION_NOT_PROXIABLE = "002";
  string public constant UG_NEW_IMPLEMENTAION_MISMATCH_VERSION = "003";

  // common errors
  string public constant CALLER_NOT_POOL_ADMIN = "100";
  string public constant CALLER_NOT_ADDRESS_PROVIDER = "101";
  string public constant INVALID_FROM_BALANCE_AFTER_TRANSFER = "102";
  string public constant INVALID_TO_BALANCE_AFTER_TRANSFER = "103";
  string public constant CALLER_NOT_ONBEHALFOF_OR_IN_WHITELIST = "104";

  // lending errors
  string public constant LEND_INVALID_LENDING_ADAPTER_ADDRESS = "400";
  string public constant LEND_INVALID_LENDING_ADAPTER_INDEX = "401";
  string public constant LEND_INVALID_LOAN_AMOUNT = "402";
  string public constant LEND_INVALID_LOAN_ASSET_ADDRESS = "403";
  string public constant LEND_INVALID_COLLATERAL_ASSET_ADDRESS = "404";
  string public constant LEND_INVALID_COLLATERAL_ID = "405";
  string public constant LEND_INVALID_MAX_BORROW_RATE = "406";
  string public constant LEND_INVALID_FLOOR_PRICE = "407";
  string public constant LEND_INVALID_WITHDRAW_ADDRESS = "408";
  string public constant LEND_INVALID_WITHDRAW_ASSET_ADDRESS = "409";
  string public constant LEND_INVALID_WITHDRAW_AMOUNT = "410";
  string public constant LEND_INVALID_POSITION_INDEX = "411";
  string public constant LEND_INVALID_POSITION_ID = "412";
  string public constant LEND_BORROW_FAILED = "413";
  string public constant LEND_INVALID_RATIO = "414";
  string public constant LEND_OVER_MAX_REPAY_AMOUNT = "415";
  string public constant LEND_REPAY_FAILED = "416";
  string public constant LEND_INCORRECT_REPAY_AMOUNT = "417";
  string public constant LEND_INVALID_NFT_ASSET_ADDRESS = "418";
  string public constant LEND_OVER_MAX_BORROW_RATE = "419";

  // fragment errors
  string public constant FRAG_INVALID_FRAGMENT_ADAPTER_ADDRESS = "500";
  string public constant FRAG_INVALID_FRAGMENT_ADAPTER_INDEX = "501";
  string public constant FRAG_INVALID_NFT_ASSET_ADDRESS = "502";
  string public constant FRAG_INVALID_FROM_ASSET_ADDRESS = "503";
  string public constant FRAG_INVALID_FROM_AMOUNT = "504";
  string public constant FRAG_INVALID_FRAGMENT_ASSET_ADDRESS = "505";
  string public constant FRAG_INVALID_FRAGMENT_AMOUNT = "506";

  // oracle errors
  string public constant ORACLE_INVALID_PRICE_ORACLE_ADAPTER_ADDRESS = "600";
  string public constant ORACLE_INVALID_PRICE_ORACLE_ADAPTER_INDEX = "601";
}