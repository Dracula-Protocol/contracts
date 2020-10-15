// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "../../IDrainController.sol";
import "./ISakeMaster.sol";

contract SakeAdapter is IVampireAdapter {
    IDrainController constant drainController = IDrainController(0x2e813f2e524dB699d279E631B0F2117856eb902C);
    ISakeMaster constant sakeMaster = ISakeMaster(0x0EC1f1573f3a2dB0Ad396c843E6a079e2a53e557);
    IERC20 constant sake = IERC20(0x066798d9ef0833ccc719076Dab77199eCbd178b0);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant sakeWethPair = IUniswapV2Pair(0xac10f17627cd6bc22719ceebf1fc524c9cfdc255);
    // token 0 - sake
    // token 1 - weth

    constructor() public {
    }

    // Victim info
    function rewardToken() external view override returns (IERC20) {
        return sake;
    }

    function poolCount() external view override returns (uint256) {
        return sakeMaster.poolLength();
    }

    function sellableRewardAmount() external view override returns (uint256) {
        return uint256(-1);
    }
    
    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256 rewardAmount, address to) external override returns(uint256) {
        require(drainController.priceIsUnderRejectionTreshold(), "Possible price manipulation, drain rejected");
        sake.transfer(address(sakeWethPair), rewardAmount);
        (uint sakeReserve, uint wethReserve,) = sakeWethPair.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, sakeReserve, wethReserve);
        sakeWethPair.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }
    
    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = sakeMaster.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = sakeMaster.userInfo(poolId, user);
        return amount;
    }
    
    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(sakeMaster), uint256(-1));
        sakeMaster.deposit(poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        sakeMaster.withdraw( poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        sakeMaster.deposit( poolId, 0);
    }
    
    function emergencyWithdraw(address, uint256 poolId) external override {
        sakeMaster.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(sakeMaster);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(sakeWethPair);
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
