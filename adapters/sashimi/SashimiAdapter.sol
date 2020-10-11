// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "./IMasterChef.sol";

contract SashimiAdapter is IVampireAdapter {
    IMasterChef constant sashimiMasterChef = IMasterChef(0x1daed74ed1dd7c9dabbe51361ac90a69d851234d);
    IERC20 constant sashimi = IERC20(0xc28e27870558cf22add83540d2126da2e4b464c2);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant sashimiWethPair = IUniswapV2Pair(0x3fa4b0b3053413684d0b658689ede7907bb4d69d);
    // token 0 - sashimi
    // token 1 - weth

    constructor() public {
    }

    // Victim info
    function rewardToken() external view override returns (IERC20) {
        return sashimi;
    }

    function poolCount() external view override returns (uint256) {
        return sashimiMasterChef.poolLength();
    }

    function sellableRewardAmount() external view override returns (uint256) {
        return uint256(-1);
    }
    
    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256 rewardAmount, address to) external override returns(uint256) {
        sashimi.transfer(address(sashimiWethPair), rewardAmount);
        (uint sashimiReserve, uint wethReserve,) = sashimiWethPair.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, sashimiReserve, wethReserve);
        sashimiWethPair.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }
    
    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = sashimiMasterChef.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = sashimiMasterChef.userInfo(poolId, user);
        return amount;
    }
    
    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(sashimiMasterChef), uint256(-1));
        sashimiMasterChef.deposit(poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        sashimiMasterChef.withdraw( poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        sashimiMasterChef.deposit( poolId, 0);
    }
    
    function emergencyWithdraw(address, uint256 poolId) external override {
        sashimiMasterChef.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(sashimiMasterChef);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(sashimiWethPair);
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
