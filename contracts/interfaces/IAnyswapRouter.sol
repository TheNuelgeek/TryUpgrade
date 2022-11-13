// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface IAnyswapRouter {
  function anySwapOutNative(address token, address to, uint toChainID) external payable;
  function anySwapOutUnderlying(address token, address to, uint256 amount, uint256 chainId) external;
  function anySwapOut(address token, address to, uint256 amount, uint256 chainId) external;
}

interface AnyswapERC20 {
  function underlying() external view returns (address);
  function Swapout(uint256 amount, address bindaddr) external;
}
