// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface IMasterVampire {
    function updateDrainAddress(address _drainAddress) external;
}

interface ILpController {
    function addLiquidity(uint256 amount) external;
}

contract DrainDistributor is Ownable {
    using SafeMath for uint256;
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IMasterVampire constant MASTER_VAMPIRE = IMasterVampire(0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099);

    uint256 public rewardShare;
    address public rewardPool;
    address public lpController;

    constructor(address _rewardPool, address _lpController) public {
        rewardShare = 150;
        rewardPool = _rewardPool;
        lpController = _lpController;
    }

    function distribute() external {
        uint256 drainWethBalance = WETH.balanceOf(address(this));
        WETH.transfer(rewardPool, drainWethBalance.mul(rewardShare).div(1000));
        ILpController(lpController).addLiquidity(drainWethBalance.mul(uint256(1000).sub(rewardShare)).div(1000));
    }

    function changeReward(uint256 _rewardShare) external onlyOwner {
        rewardShare = _rewardShare;
    }

    function changeLp(address _lpController) external onlyOwner {
        lpController = _lpController;
    }
}
