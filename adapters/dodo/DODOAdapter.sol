// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Router02.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "../../IDrainController.sol";
import "./interfaces/IDODO.sol";
import "./IDODOMine.sol";

contract DODOAdapter is IVampireAdapter {
    IDrainController constant drainController = IDrainController(0x2e813f2e524dB699d279E631B0F2117856eb902C);
    IUniswapV2Router02 constant router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IDODOMine constant dodoMine = IDODOMine(0xaeD7384F03844Af886b830862FF0a7AFce0a632C);
    IDODO constant dodoUSDT = IDODO(0x8876819535b48b551C9e97EBc07332C7482b4b2d);
    IERC20 constant dodo = IERC20(0x43Dfc4159D86F3A37A5A4B3D4580b888ad7d4DDd);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

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
        require(drainController.priceIsUnderRejectionTreshold(), "Possible price manipulation, drain rejected");
        /*
            1. Swap DODO for USDT on DODODEX
            2. Swap USDT for WETH on Uniswap
        */
        // 1
        dodo.approve(address(dodoUSDT), uint256(-1));
        uint256 usdtAmount = dodoUSDT.sellBaseToken(rewardAmount, 0, new bytes(0));
        require(usdtAmount > 0, "DODO to USDT failed");

        // 2
        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(weth);
        uint[] memory amounts = router.getAmountsOut(usdtAmount, path);
        usdt.approve(address(router), uint256(-1));
        router.swapTokensForExactETH(usdtAmount, amounts[amounts.length - 1], path, to, block.timestamp);
        return amounts[amounts.length - 1];
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
        return address(0);
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
