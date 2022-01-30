// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import { IFlashLoanReceiver, ILendingPoolAddressesProvider, ILendingPool, IERC20 } from "./interfaces/FlashLoanInterfaces.sol";
import { SafeERC20, SafeMath } from "./libraries/FlashLoanLibraries.sol";

abstract contract FlashLoanReceiverBase is IFlashLoanReceiver {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  ILendingPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
  ILendingPool public immutable override LENDING_POOL;

  constructor(ILendingPoolAddressesProvider provider) {
    ADDRESSES_PROVIDER = provider;
    LENDING_POOL = ILendingPool(provider.getLendingPool());
  }
}
