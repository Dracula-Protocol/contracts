// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "../../IDrainController.sol";
import "./IMasterChef.sol";

contract XSPAdapter is IVampireAdapter {
    IDrainController constant drainController = IDrainController(0x2e813f2e524dB699d279E631B0F2117856eb902C);
    IMasterChef constant xspMasterChef = IMasterChef(0xEbF9F6E03a6f5Dba658c3a3c2E14514E27EcC444);
    IERC20 constant xsp = IERC20(0x9b06d48e0529ecf05905ff52dd426ebec0ea3011);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant xspWethPair = IUniswapV2Pair(0x5fa78fa8f5d6371ced774e0d306a58fd1b8b03e3);
    // token 0 - xsp
    // token 1 - weth

    constructor() public {
    }

    // Victim info
    function rewardToken() external view override returns (IERC20) {
        return xsp;
    }

    function poolCount() external view override returns (uint256) {
        return xspMasterChef.poolLength();
    }

    function sellableRewardAmount() external view override returns (uint256) {
        return uint256(-1);
    }
    
    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256 rewardAmount, address to) external override returns(uint256) {
        require(drainController.priceIsUnderRejectionTreshold(), "Possible price manipulation, drain rejected");
        xsp.transfer(address(xspWethPair), rewardAmount);
        (uint xspReserve, uint wethReserve,) = xspWethPair.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, xspReserve, wethReserve);
        xspWethPair.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }
    
    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = xspMasterChef.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = xspMasterChef.userInfo(poolId, user);
        return amount;
    }
    
    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(xspMasterChef), uint256(-1));
        xspMasterChef.deposit(poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        xspMasterChef.withdraw( poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        xspMasterChef.deposit( poolId, 0);
    }
    
    function emergencyWithdraw(address, uint256 poolId) external override {
        xspMasterChef.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(xspMasterChef);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(xspWethPair);
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
