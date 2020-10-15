// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "../../IDrainController.sol";
import "./IMasterChef.sol";

contract SushiAdapter is IVampireAdapter {
    IDrainController constant drainController = IDrainController(0x2e813f2e524dB699d279E631B0F2117856eb902C);
    IMasterChef constant sushiMasterChef = IMasterChef(0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd);
    IERC20 constant sushi = IERC20(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant sushiWethPair = IUniswapV2Pair(0x795065dCc9f64b5614C407a6EFDC400DA6221FB0);
    // token 0 - sushi
    // token 1 - weth

    constructor() public {
    }

    // Victim info
    function rewardToken() external view override returns (IERC20) {
        return sushi;
    }

    function poolCount() external view override returns (uint256) {
        return sushiMasterChef.poolLength();
    }

    function sellableRewardAmount() external view override returns (uint256) {
        return uint256(-1);
    }
    
    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256 rewardAmount, address to) external override returns(uint256) {
        require(drainController.priceIsUnderRejectionTreshold(), "Possible price manipulation, drain rejected");
        sushi.transfer(address(sushiWethPair), rewardAmount);
        (uint sushiReserve, uint wethReserve,) = sushiWethPair.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, sushiReserve, wethReserve);
        sushiWethPair.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }
    
    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = sushiMasterChef.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = sushiMasterChef.userInfo(poolId, user);
        return amount;
    }
    
    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(sushiMasterChef), uint256(-1));
        sushiMasterChef.deposit(poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        sushiMasterChef.withdraw( poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        sushiMasterChef.deposit( poolId, 0);
    }
    
    function emergencyWithdraw(address, uint256 poolId) external override {
        sushiMasterChef.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(sushiMasterChef);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(sushiWethPair);
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
