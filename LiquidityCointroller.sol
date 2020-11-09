// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../interfaces/IUniswapV2Router02.sol";

contract LiquidityCointroller {
    using SafeMath for uint256;
    IERC20 constant dracula = IERC20(0xb78B3320493a4EFaa1028130C5Ba26f0B6085Ef8);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant drcWethPair = IUniswapV2Pair(0x276e62c70e0b540262491199bc1206087f523af6);
    IUniswapV2Router02 constant uniRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    // token 0 - Dracula
    // token 1 - weth

    constructor() public {
        dracula.approve(address(uniRouter), uint256(-1));
    }

    function addLiquidity() external {
        uint256 halfWethBalance = weth.balanceOf(address(this)).div(2);
        weth.transfer(address(drcWethPair), halfWethBalance);
        (uint256 draculaReserve, uint256 wethReserve) = drcWethPair.getReserves();
        uint256 amountOutput = UniswapV2Library.getAmountOut(halfWethBalance, draculaReserve, wethReserve);
        drcWethPair.swap(uint256(0), amountOutput, address(this), new bytes(0));
        uint256 quoteAmount = UniswapV2Library.quote(halfWethBalance, draculaReserve, wethReserve);
        uniRouter.addLiquidity(address(dracula), address(weth), quoteAmount, quoteAmount, halfWethBalance, dead);
        dracula.burn(dracula.balanceOf(address(this)));
    }
}
