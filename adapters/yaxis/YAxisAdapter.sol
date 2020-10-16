// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "../../IDrainController.sol";
import "./IYAxisMaster.sol";

contract YAxisAdapter is IVampireAdapter {
    IDrainController constant DRAIN_CONTROLLER = IDrainController(0x2e813f2e524dB699d279E631B0F2117856eb902C);
    IYAxisMaster constant YAXIS_MASTER = IYAxisMaster(0xC330E7e73717cd13fb6bA068Ee871584Cf8A194F);
    IERC20 constant YAXIS = IERC20(0x066798d9ef0833ccc719076Dab77199eCbd178b0);
    IUniswapV2Pair constant YAXIS_WETH_PAIR = IUniswapV2Pair(0x1107B6081231d7F256269aD014bF92E041cb08df);
    // token 0 - YAXIS
    // token 1 - WETH

    // Victim info
    function rewardToken() external view override returns (IERC20) {
        return YAXIS;
    }

    function poolCount() external view override returns (uint256) {
        return YAXIS_MASTER.poolLength();
    }

    function sellableRewardAmount() external view override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256 rewardAmount, address to) external override returns(uint256) {
        require(DRAIN_CONTROLLER.priceIsUnderRejectionTreshold(), "Possible price manipulation, drain rejected");
        YAXIS.transfer(address(YAXIS_WETH_PAIR), rewardAmount);
        (uint yaxisReserve, uint wethReserve,) = YAXIS_WETH_PAIR.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, yaxisReserve, wethReserve);
        YAXIS_WETH_PAIR.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = YAXIS_MASTER.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = YAXIS_MASTER.userInfo(poolId, user);
        return amount;
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(YAXIS_MASTER), uint256(-1));
        YAXIS_MASTER.deposit(poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        YAXIS_MASTER.withdraw(poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        YAXIS_MASTER.deposit(poolId, 0);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        YAXIS_MASTER.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(YAXIS_MASTER);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(YAXIS_WETH_PAIR);
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
