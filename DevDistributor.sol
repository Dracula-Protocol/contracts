// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./DraculaToken.sol";

interface IMasterVampire {
    function updateDevAddress(address _devAddress) external;
}

contract DevDistributor is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for DraculaToken;
    DraculaToken public dracula;

    IMasterVampire constant MASTER_VAMPIRE = IMasterVampire(0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099);

    uint256 public rewardShare;
    address public rewardPool;
    address public devAddress;

    constructor(DraculaToken _draculaToken, address _rewardPool) public {
        dracula = _draculaToken;
        rewardShare = 500;
        rewardPool = _rewardPool;
        devAddress = 0xa896e4bd97a733F049b23d2AcEB091BcE01f298d;
    }

    function distribute() external {
        uint256 devDrcBalance = dracula.balanceOf(address(this));
        dracula.transfer(rewardPool, devDrcBalance.mul(rewardShare).div(1000));
        dracula.transfer(devAddress, devDrcBalance.mul(uint256(1000).sub(rewardShare)).div(1000));
    }

    function changeDev(address dev) external onlyOwner {
        MASTER_VAMPIRE.updateDevAddress(dev);
    }

    function changeReward(uint256 _rewardShare) external onlyOwner {
        rewardShare = _rewardShare;
    }
}