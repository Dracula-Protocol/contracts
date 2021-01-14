// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../interfaces/IUniswapV2Router02.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "../../IDrainController.sol";
import "./ITrueFarm.sol";

contract TruefiAdapter is IVampireAdapter {
  IDrainController constant drainController = IDrainController(0x2e813f2e524dB699d279E631B0F2117856eb902C);
  ITrueFarm constant trueFarm = ITrueFarm(0xED45Cf4895C110f464cE857eBE5f270949eC2ff4);
  IUniswapV2Router02 constant router = IUniswapV2Router02(0x1d5C6F1607A171Ad52EFB270121331b3039dD83e);
  IERC20 constant tru = IERC20(0x4C19596f5aAfF459fA38B0f7eD92F11AE6543784);
  IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  IUniswapV2Pair constant truWethPair = IUniswapV2Pair(0xeC6a6b7dB761A5c9910bA8fcaB98116d384b1B85);

  constructor() public {}

  // Victim info
  function rewardToken() external view override returns (IERC20) {
    return tru;
  }

  function poolCount() external view override returns (uint256) { 
    return trueFarm.totalStaked();
  }

  function sellableRewardAmount() external view override returns (uint256) {
    return uint256(-1);
  }

  // Victim actions, requires impersonation via delegatecall
  function sellRewardForWeth(address, uint256 rewardAmount, address to) external override returns(uint256) {
    require(drainController.priceIsUnderRejectionTreshold(), "Possible price manipulation, drain rejected");
    address[] memory path = new address[](2);
    path[0] = address(tru);
    path[1] = address(weth);
    uint[] memory amounts = router.getAmountsOut(rewardAmount, path);
    tru.approve(address(router), uint256(-1));
    amounts = router.swapExactTokensForTokens(rewardAmount, amounts[amounts.length - 1], path, to, block.timestamp );
    return amounts[amounts.length - 1];
  }

  // Pool info
  function lockableToken(uint256 poolId) external view override returns (IERC20) {
    return trueFarm.stakingToken();
  }

  function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
    return trueFarm.staked(user);
  }

  // Pool actions, requires impersonation via delegatecall
  function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
    IVampireAdapter adapter = IVampireAdapter(_adapter);
    adapter.lockableToken(poolId).approve(address(trueFarm), uint256(-1));
    trueFarm.deposit(amount);
  }

  function withdraw(address, uint256 poolId, uint256 amount) external override {
    trueFarm.unstake(amount);
  }

  function claimReward(address, uint256 poolId) external override {
    trueFarm.claim();
  }
  
  function emergencyWithdraw(address, uint256 poolId) external override {
    require(false, "not implemented");
  }

  // Service methods
  function poolAddress(uint256) external view override returns (address) {
    return address(trueFarm);
  }

  function rewardToWethPool() external view override returns (address) {
    return address(truWethPair);
  }
  
  function lockedValue(address, uint256) external override view returns (uint256) {
    require(false, "not implemented");
  }    

  function totalLockedValue(uint256) external override view returns (uint256) {
    require(false, "not implemented");
  }

  function normalizedAPY(uint256) external override view returns (uint256) {
    require(false, "not implemented");
  }
}
