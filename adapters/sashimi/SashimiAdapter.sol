// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "../../IDrainController.sol";
import "./IMasterChef.sol";

contract SashimiAdapter is IVampireAdapter {
    IDrainController constant DRAIN_CONTROLLER = IDrainController(0x2e813f2e524dB699d279E631B0F2117856eb902C);
    IMasterChef constant SASHIMI_MASTERCHEF = IMasterChef(0x1DaeD74ed1dD7C9Dabbe51361ac90A69d851234D);
    IERC20 constant SASHIMI = IERC20(0xC28E27870558cF22ADD83540d2126da2e4b464c2);
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant WETH_SASHIMI_PAIR = IUniswapV2Pair(0x3fA4B0b3053413684d0B658689Ede7907bB4D69D);
    // token 0 - WETH
    // token 1 - SASHIMI

    // Victim info
    function rewardToken() external view override returns (IERC20) {
        return SASHIMI;
    }

    function poolCount() external view override returns (uint256) {
        return SASHIMI_MASTERCHEF.poolLength();
    }

    function sellableRewardAmount() external view override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256 rewardAmount, address to) external override returns(uint256) {
        require(DRAIN_CONTROLLER.priceIsUnderRejectionTreshold(), "Possible price manipulation, drain rejected");
        SASHIMI.transfer(address(WETH_SASHIMI_PAIR), rewardAmount);
        (uint wethReserve, uint sashimiReserve,) = WETH_SASHIMI_PAIR.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, sashimiReserve, wethReserve);
        WETH_SASHIMI_PAIR.swap(amountOutput, uint(0), to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = SASHIMI_MASTERCHEF.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = SASHIMI_MASTERCHEF.userInfo(poolId, user);
        return amount;
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(SASHIMI_MASTERCHEF), uint256(-1));
        SASHIMI_MASTERCHEF.deposit(poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        SASHIMI_MASTERCHEF.withdraw(poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        SASHIMI_MASTERCHEF.deposit(poolId, 0);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        SASHIMI_MASTERCHEF.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(SASHIMI_MASTERCHEF);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(WETH_SASHIMI_PAIR);
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
