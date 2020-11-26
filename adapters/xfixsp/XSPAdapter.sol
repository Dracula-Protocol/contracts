// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "../../IDrainController.sol";
import "./IMasterChef.sol";

contract XSPAdapter is IVampireAdapter {
    IDrainController constant DRAIN_CONTROLLER = IDrainController(0x2e813f2e524dB699d279E631B0F2117856eb902C);
    address constant MASTER_VAMPIRE = 0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099;
    IMasterChef constant XSP_MASTERCHEF = IMasterChef(0xEbF9F6E03a6f5Dba658c3a3c2E14514E27EcC444);
    IERC20 constant XSP = IERC20(0x9b06D48E0529ecF05905fF52DD426ebEc0EA3011);
    IUniswapV2Pair constant XSP_WETH_PAIR = IUniswapV2Pair(0x5fA78fA8F5d6371ceD774e0D306a58fD1b8b03e3);
    // token 0 - XSP
    // token 1 - WETH

    // Victim info
    function rewardToken() external view override returns (IERC20) {
        return XSP;
    }

    function poolCount() external view override returns (uint256) {
        return XSP_MASTERCHEF.poolLength();
    }

    function sellableRewardAmount() external view override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256 rewardAmount, address to) external override returns(uint256) {
        require(DRAIN_CONTROLLER.priceIsUnderRejectionTreshold(), "Possible price manipulation, drain rejected");
        XSP.transfer(address(XSP_WETH_PAIR), rewardAmount);
        (uint xspReserve, uint wethReserve,) = XSP_WETH_PAIR.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, xspReserve, wethReserve);
        XSP_WETH_PAIR.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = XSP_MASTERCHEF.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = XSP_MASTERCHEF.userInfo(poolId, user);
        return amount;
    }

    function pendingReward(uint256 poolId) external view override returns (uint256) {
        return XSP_MASTERCHEF.pendingXSP(poolId, MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(XSP_MASTERCHEF), uint256(-1));
        XSP_MASTERCHEF.deposit(poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        XSP_MASTERCHEF.withdraw(poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        XSP_MASTERCHEF.deposit(poolId, 0);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        XSP_MASTERCHEF.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(XSP_MASTERCHEF);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(XSP_WETH_PAIR);
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
