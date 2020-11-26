// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "../../IDrainController.sol";
import "./ITorchShip.sol";

contract StrudelAdapter is IVampireAdapter {
    using SafeMath for uint256;
    IDrainController constant drainController = IDrainController(0x2e813f2e524dB699d279E631B0F2117856eb902C);
    address constant MASTER_VAMPIRE = 0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099;
    ITorchShip constant strudelTorchShip = ITorchShip(0x517b091FdB87A42c879BbB849444E76A324D53c8);
    IERC20 constant strudel = IERC20(0x297D33e17e61C2Ddd812389C2105193f8348188a);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant strudelWethPair = IUniswapV2Pair(0x29b0aA11dE97f6d5A3293d980990e820BDA5FBAb);
    uint256 constant BLOCKS_PER_YEAR = 2336000;
    // token 0 - strudel
    // token 1 - weth

    // Victim info
    function rewardToken() external view override returns (IERC20) {
        return strudel;
    }

    function poolCount() external view override returns (uint256) {
        return strudelTorchShip.poolLength();
    }

    function sellableRewardAmount() external view override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256 rewardAmount, address to) external override returns(uint256) {
        require(drainController.priceIsUnderRejectionTreshold(), "Possible price manipulation, drain rejected");
        strudel.transfer(address(strudelWethPair), rewardAmount);
        (uint strudelReserve, uint wethReserve,) = strudelWethPair.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, strudelReserve, wethReserve);
        strudelWethPair.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = strudelTorchShip.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = strudelTorchShip.userInfo(poolId, user);
        return amount;
    }

    function pendingReward(uint256 poolId) external view override returns (uint256) {
        return strudelTorchShip.pendingStrudel(poolId, MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(strudelTorchShip), uint256(-1));
        strudelTorchShip.deposit(poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        strudelTorchShip.withdraw(poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        strudelTorchShip.deposit(poolId, 0);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        strudelTorchShip.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(strudelTorchShip);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(strudelWethPair);
    }

    function lpTokenValue(uint256 amount, IUniswapV2Pair lpToken) public view returns(uint256) {
        (uint256 token0Reserve, uint256 token1Reserve,) = lpToken.getReserves();
        address token0 = lpToken.token0();
        address token1 = lpToken.token1();
        if (token0 == address(weth)) {
            return amount.mul(token0Reserve).mul(2).div(lpToken.totalSupply());
        }

        if (token1 == address(weth)) {
            return amount.mul(token1Reserve).mul(2).div(lpToken.totalSupply());
        }

        if (IUniswapV2Factory(lpToken.factory()).getPair(token0, address(weth)) != address(0)) {
            (uint256 wethReserve, uint256 token0ToWethReserve) = UniswapV2Library.getReserves(lpToken.factory(), address(weth), token0);
            uint256 tmp = amount.mul(token0Reserve).mul(wethReserve).mul(2);
            return tmp.div(token0ToWethReserve).div(lpToken.totalSupply());
        }

        require(
            IUniswapV2Factory(lpToken.factory()).getPair(token1, address(weth)) != address(0),
            "Neither token0-weth nor token1-weth pair exists");
        (uint256 wethReserve, uint256 token1ToWethReserve) = UniswapV2Library.getReserves(lpToken.factory(), address(weth), token1);
        uint256 tmp = amount.mul(token1Reserve).mul(wethReserve).mul(2);
        return tmp.div(token1ToWethReserve).div(lpToken.totalSupply());
    }

    function lockedValue(address user, uint256 poolId) external override view returns (uint256) {
        StrudelAdapter adapter = StrudelAdapter(this);
        return adapter.lpTokenValue(adapter.lockedAmount(user, poolId),IUniswapV2Pair(address(adapter.lockableToken(poolId))));
    }

    function totalLockedValue(uint256 poolId) external override view returns (uint256) {
        StrudelAdapter adapter = StrudelAdapter(this);
        IUniswapV2Pair lockedToken = IUniswapV2Pair(address(adapter.lockableToken(poolId)));
        return adapter.lpTokenValue(lockedToken.balanceOf(adapter.poolAddress(poolId)), lockedToken);
    }

    function normalizedAPY(uint256 poolId) external override view returns (uint256) {
        StrudelAdapter adapter = StrudelAdapter(this);
        (,uint256 allocationPoints,,) = strudelTorchShip.poolInfo(poolId);
        uint256 strudelPerBlock = strudelTorchShip.strudelPerBlock();
        uint256 totalAllocPoint = strudelTorchShip.totalAllocPoint();
        uint256 multiplier = strudelTorchShip.getMultiplier(block.number - 1, block.number);
        uint256 rewardPerBlock = multiplier.mul(strudelPerBlock).mul(allocationPoints).div(totalAllocPoint);
        (uint256 strudelReserve, uint256 wethReserve,) = strudelWethPair.getReserves();
        uint256 valuePerYear = rewardPerBlock.mul(wethReserve).mul(BLOCKS_PER_YEAR).div(strudelReserve);
        return valuePerYear.mul(1 ether).div(adapter.totalLockedValue(poolId));
    }
}
