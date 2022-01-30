// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import { FlashLoanReceiverBase } from "./FlashLoanReceiverBase.sol";
import { ILendingPool, ILendingPoolAddressesProvider, IERC20 } from "./interfaces/FlashLoanInterfaces.sol";
import { SafeMath } from "./libraries/FlashLoanLibraries.sol";
import { IUniswapV2Router02 } from "./interfaces/IUniswapV2Router02.sol";
import { IDMMRouter02 } from "./interfaces/IDMMRouter02.sol";
import { IDMMFactory } from "./interfaces/IDMMFactory.sol";
import "hardhat/console.sol";

/** 
    !!!
    Never keep funds permanently on your FlashLoanReceiverBase contract as they could be 
    exposed to a 'griefing' attack, where the stored funds are used by an attacker.
    !!!
 */

contract MyArbitrage is FlashLoanReceiverBase {
  using SafeMath for uint256;

  address private owner = msg.sender;
  IUniswapV2Router02 private uniswapRouter;
  IUniswapV2Router02 private sushiswapRouter;
  IDMMFactory private kyberswapFactory;
  IDMMRouter02 private kyberswapRouter;

  constructor(
    ILendingPoolAddressesProvider _addressProvider,
    address _uniswapRouterAddress,
    address _kyberswapFactoryAddress,
    address _kyberswapRouterAddress,
    address _sushiswapRouterAddress
  ) FlashLoanReceiverBase(_addressProvider) {
    uniswapRouter = IUniswapV2Router02(_uniswapRouterAddress);
    kyberswapFactory = IDMMFactory(_kyberswapFactoryAddress);
    kyberswapRouter = IDMMRouter02(_kyberswapRouterAddress);
    sushiswapRouter = IUniswapV2Router02(_sushiswapRouterAddress);
  }

  modifier ownerOnly() {
    require(owner == msg.sender, "For owner only");
    _;
  }

  function swapOnKyberswap(address from, address to) private {
    IERC20 inputToken = IERC20(from);
    IERC20 outputToken = IERC20(to);
    uint256 amountIn = inputToken.balanceOf(address(this));

    IERC20(from).approve(address(kyberswapRouter), amountIn);

    address poolAddress = kyberswapFactory.getUnamplifiedPool(
      inputToken,
      outputToken
    );
    address[] memory poolsPath = new address[](1);
    poolsPath[0] = poolAddress;

    IERC20[] memory path = new IERC20[](2);
    path[0] = inputToken;
    path[1] = outputToken;

    kyberswapRouter.swapExactTokensForTokens(
      amountIn,
      0,
      poolsPath,
      path,
      address(this),
      block.timestamp + 60
    );
  }

  function swapOnSushiswap(address from, address to) private {
    address[] memory path = new address[](2);
    path[0] = from;
    path[1] = to;
    uint256 amountIn = IERC20(from).balanceOf(address(this));
    IERC20(from).approve(address(sushiswapRouter), amountIn);
    IERC20 f = IERC20(from);

    console.log("Swapping on sushiswap");
    console.log("From: %s - %s", from, f.balanceOf(address(this)));
    console.log("To: %s", to);

    sushiswapRouter.swapExactTokensForTokens(
      amountIn,
      0,
      path,
      address(this),
      block.timestamp + 60
    );
    console.log("Swapping on sushiswap - success");
    console.log(
      "New balance: %s - %s",
      to,
      IERC20(to).balanceOf(address(this))
    );
  }

  function swapOnUniswap(address from, address to) private {
    address[] memory path = new address[](2);
    path[0] = from;
    path[1] = to;
    uint256 amountIn = IERC20(from).balanceOf(address(this));
    IERC20(from).approve(address(uniswapRouter), amountIn);
    IERC20 f = IERC20(from);

    console.log("Swapping on uniswap");
    console.log("From: %s - %s", from, f.balanceOf(address(this)));
    console.log("To: %s", to);

    uniswapRouter.swapExactTokensForTokens(
      amountIn,
      0,
      path,
      address(this),
      block.timestamp + 60
    );
    console.log("Swapping on uniswap - success");
    console.log(
      "New balance: %s - %s",
      to,
      IERC20(to).balanceOf(address(this))
    );
  }

  /**
        This function is called after your contract has received the flash loaned amount
     */
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external override returns (bool) {
    uint256 startGas = gasleft();
    console.log(
      "Flash loan: amount - %s, premium - %s",
      amounts[0],
      premiums[0]
    );
    (string[] memory exchanges, address[] memory cryptos) = abi.decode(
      params,
      (string[], address[])
    );

    for (uint256 i = 0; i < exchanges.length; i++) {
      string memory exchange = exchanges[i];
      address from = cryptos[i];
      address to = i == cryptos.length - 1 ? cryptos[0] : cryptos[i + 1];

      if (keccak256(bytes(exchange)) == keccak256(bytes("UNISWAP"))) {
        swapOnUniswap(from, to);
      } else if (keccak256(bytes(exchange)) == keccak256(bytes("KYBERSWAP"))) {
        swapOnKyberswap(from, to);
      } else if (keccak256(bytes(exchange)) == keccak256(bytes("SUSHISPWAP"))) {
        swapOnSushiswap(from, to);
      } else {
        require(false);
      }
    }
    for (uint256 i = 0; i < assets.length; i++) {
      uint256 amountOwing = amounts[i].add(premiums[i]);
      IERC20(assets[i]).approve(address(LENDING_POOL), amountOwing);
    }

    uint256 gasUsed = startGas - gasleft();

    console.log("Gas used: %s", gasUsed);

    return true;
  }

  function arbitrage(
    string[] memory exchanges,
    address[] memory cryptos,
    uint256 amountToBorrow
  ) public ownerOnly {
    require(exchanges.length == cryptos.length);

    address receiverAddress = address(this);

    address[] memory assets = new address[](1);
    assets[0] = cryptos[0];

    uint256[] memory amounts = new uint256[](1);
    amounts[0] = amountToBorrow;

    // 0 = no debt, 1 = stable, 2 = variable
    uint256[] memory modes = new uint256[](1);
    modes[0] = 0;

    address onBehalfOf = address(this);
    uint16 referralCode = 0;

    bytes memory params = abi.encode(exchanges, cryptos);

    LENDING_POOL.flashLoan(
      receiverAddress,
      assets,
      amounts,
      modes,
      onBehalfOf,
      params,
      referralCode
    );
  }
}
