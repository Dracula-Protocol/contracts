// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../interfaces/IUniswapV2Router02.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "../../IDrainController.sol";
import "./ILuaMasterFarmer.sol";

contract LuaAdapter is IVampireAdapter {
    IDrainController constant drainController = IDrainController(0x2e813f2e524dB699d279E631B0F2117856eb902C);
    ILuaMasterFarmer constant luaMasterFarmer = ILuaMasterFarmer(0xb67D7a6644d9E191Cac4DA2B88D6817351C7fF62);
    IUniswapV2Router02 constant router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IERC20 constant lua = IERC20(0xB1f66997A5760428D3a87D68b90BfE0aE64121cC);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    constructor() public {}

    // Victim info
    function rewardToken() external override view returns (IERC20) {
        return lua;
    }

    function poolCount() external override view returns (uint256) {
        return luaMasterFarmer.poolLength();
    }

    function sellableRewardAmount() external override view returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(
        address,
        uint256 rewardAmount,
        address to
    ) external override returns (uint256) {
        require(drainController.priceIsUnderRejectionTreshold(), "Possible price manipulation, drain rejected");
        address[] memory path = new address[](3);
        path[0] = address(lua);
        path[1] = address(usdc);
        path[2] = address(weth);
        uint[] memory amounts = router.getAmountsOut(rewardAmount, path);
        lua.approve(address(router), uint256(-1));
        amounts = router.swapExactTokensForTokens(rewardAmount, amounts[amounts.length - 1], path, to, block.timestamp );
        return amounts[amounts.length - 1];
    }

    // Pool info
    function lockableToken(uint256 poolId)
        external
        override
        view
        returns (IERC20)
    {
        (IERC20 lpToken, , , ) = luaMasterFarmer.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId)
        external
        override
        view
        returns (uint256)
    {
        (uint256 amount, , ) = luaMasterFarmer.userInfo(poolId, user);
        return amount;
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(
        address _adapter,
        uint256 poolId,
        uint256 amount
    ) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(luaMasterFarmer), uint256(-1));
        luaMasterFarmer.deposit(poolId, amount);
    }

    function withdraw(
        address,
        uint256 poolId,
        uint256 amount
    ) external override {
        luaMasterFarmer.withdraw(poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        luaMasterFarmer.claimReward(poolId);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        luaMasterFarmer.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external override view returns (address) {
        return address(luaMasterFarmer);
    }

    function rewardToWethPool() external override view returns (address) {
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
