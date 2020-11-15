// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "../../IDrainController.sol";
import "./ISakeMaster.sol";

contract SakeAdapter is IVampireAdapter {
    IDrainController constant DRAIN_CONTROLLER = IDrainController(0x2e813f2e524dB699d279E631B0F2117856eb902C);
    address constant MASTER_VAMPIRE = 0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099;
    ISakeMaster constant SAKE_MASTER = ISakeMaster(0x0EC1f1573f3a2dB0Ad396c843E6a079e2a53e557);
    IERC20 constant SAKE = IERC20(0x066798d9ef0833ccc719076Dab77199eCbd178b0);
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant SAKE_WETH_PAIR = IUniswapV2Pair(0xAC10f17627Cd6bc22719CeEBf1fc524C9Cfdc255);
    // token 0 - SAKE
    // token 1 - WETH

    // Victim info
    function rewardToken() external view override returns (IERC20) {
        return SAKE;
    }

    function poolCount() external view override returns (uint256) {
        return SAKE_MASTER.poolLength();
    }

    function sellableRewardAmount() external view override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256 rewardAmount, address to) external override returns(uint256) {
        require(DRAIN_CONTROLLER.priceIsUnderRejectionTreshold(), "Possible price manipulation, drain rejected");
        SAKE.transfer(address(SAKE_WETH_PAIR), rewardAmount);
        (uint sakeReserve, uint wethReserve,) = SAKE_WETH_PAIR.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, sakeReserve, wethReserve);
        SAKE_WETH_PAIR.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = SAKE_MASTER.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = SAKE_MASTER.userInfo(poolId, user);
        return amount;
    }

    function pendingReward(uint256 poolId) external view override returns (uint256) {
        return SAKE_MASTER.pendingSake(poolId, MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(SAKE_MASTER), uint256(-1));
        SAKE_MASTER.deposit(poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        SAKE_MASTER.withdraw(poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        SAKE_MASTER.deposit(poolId, 0);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        SAKE_MASTER.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(SAKE_MASTER);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(SAKE_WETH_PAIR);
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
