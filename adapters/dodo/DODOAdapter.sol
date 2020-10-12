// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "./IDODOMine.sol";

contract DODOAdapter is IVampireAdapter {
    IDODOMine constant dodoMine = IDODOMine(0xaeD7384F03844Af886b830862FF0a7AFce0a632C);
    IERC20 constant dodo = IERC20(0x43Dfc4159D86F3A37A5A4B3D4580b888ad7d4DDd);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant dodoWethPair = IUniswapV2Pair(0x68Fa181c720C07B7FF7412220E2431ce90A65A14);
    // token 0 - dodo
    // token 1 - weth

    // Victim info
    function rewardToken() external view override returns (IERC20) {
        return dodo;
    }

    function poolCount() external view override returns (uint256) {
        return dodoMine.poolLength();
    }

    function sellableRewardAmount() external view override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256 rewardAmount, address to) external override returns(uint256) {
        dodo.transfer(address(dodoWethPair), rewardAmount);
        (uint dodoReserve, uint wethReserve,) = dodoWethPair.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, dodoReserve, wethReserve);
        dodoWethPair.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (address lpToken,,,) = dodoMine.poolInfos(poolId);
        return IERC20(lpToken);
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = dodoMine.userInfo(poolId, user);
        return amount;
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        IERC20 lpToken = adapter.lockableToken(poolId);
        lpToken.approve(address(dodoMine), uint256(-1));
        dodoMine.deposit(address(lpToken), amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        (address lpToken,,,) = dodoMine.poolInfos(poolId);
        dodoMine.withdraw(lpToken, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        (address lpToken,,,) = dodoMine.poolInfos(poolId);
        dodoMine.claim(lpToken);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        (address lpToken,,,) = dodoMine.poolInfos(poolId);
        dodoMine.emergencyWithdraw(lpToken);
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(dodoMine);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(dodoWethPair);
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
