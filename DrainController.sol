// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IUniswapV2Pair.sol";

interface IMasterVampire {
    function drain(uint256 pid) external;
}

library UQ112x112 {
    uint224 constant Q112 = 2**112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}

contract DrainController is Ownable
{
    using SafeMath for uint256;
    using UQ112x112 for uint224;

    IMasterVampire constant MASTER_VAMPIRE = IMasterVampire(0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099);
    IUniswapV2Pair constant DRC_WETH_PAIR = IUniswapV2Pair(0x276E62C70e0B540262491199Bc1206087f523AF6);
    uint constant PRICE_UPDATE_MIN_DELAY = 1 hours;

    uint lastCumulativePriceTimestamp;
    uint lastCumulativePrice;
    
    uint224 public price;
    uint256 public drainRejectionTreshold;

    constructor() public {
        drainRejectionTreshold = 30;
        lastCumulativePriceTimestamp = 1602679086;
        lastCumulativePrice = 173408361600511906516768678672263980640; 
        updatePrice();
    }

    function updatePrice() public {
        (,,uint currentTimestamp) = DRC_WETH_PAIR.getReserves();
        uint256 timeElapsed = currentTimestamp - lastCumulativePriceTimestamp;
        require(timeElapsed > PRICE_UPDATE_MIN_DELAY || msg.sender == owner(), "Too early to update cumulative price");
        uint256 currentCumulativePrice = DRC_WETH_PAIR.price0CumulativeLast();
        price = uint224(currentCumulativePrice.sub(lastCumulativePrice).div(timeElapsed));
        lastCumulativePriceTimestamp = currentTimestamp;
        lastCumulativePrice = currentCumulativePrice;
    }

    function priceIsUnderRejectionTreshold() view public returns(bool) {
        (uint112 drcReserves, uint112 wethReserves,) = DRC_WETH_PAIR.getReserves();
        uint224 currentPrice = UQ112x112.encode(wethReserves).uqdiv(drcReserves);
        return currentPrice < (price + price * 100 / drainRejectionTreshold);
    }

    function massDrain(uint256[] memory pids) public {
        for (uint i = 0; i < pids.length; i++) {
            MASTER_VAMPIRE.drain(pids[i]);
        }
    }

    function updateTreshold(uint256 _drainRejectionTreshold) public onlyOwner {
        drainRejectionTreshold = _drainRejectionTreshold;
    }
}

