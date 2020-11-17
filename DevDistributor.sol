// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./DraculaToken.sol";

interface IMasterVampire {
    function updateDevAddress(address _devAddress) external;
}

/**
* @title Receives rewards from MasterVampire and redistributes to a developer fund and a DRC reward pool.
*/
contract DevDistributor is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for DraculaToken;

    DraculaToken public dracula;
    IMasterVampire constant MASTER_VAMPIRE = IMasterVampire(0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099);

    uint256 public rewardPoolShare;
    address public rewardPool;
    address public devFundAddress;

    /**
    * @notice Construct the contract
    * @param draculaToken_ instance of the Draculatoken
    * @param rewardPool_ address of the reward pool
    */
    constructor(DraculaToken draculaToken_, address rewardPool_) public {
        dracula = draculaToken_;
        rewardPoolShare = 500;
        rewardPool = rewardPool_;
        devFundAddress = 0xa896e4bd97a733F049b23d2AcEB091BcE01f298d;
    }

    /**
    * @notice Distributes DRC from the contracts balance
    */
    function distribute() external {
        uint256 devDrcBalance = dracula.balanceOf(address(this));
        uint256 rewardPoolAmt = devDrcBalance.mul(rewardPoolShare).div(1000);
        uint256 devAmt = devDrcBalance.sub(rewardPoolAmt);
        dracula.safeTransfer(rewardPool, rewardPoolAmt);
        dracula.safeTransfer(devFundAddress, devAmt);
    }

    /**
    * @notice Changes the dev associated with MasterVampire
    * @param dev the new address
    */
    function changeDev(address dev) external onlyOwner {
        MASTER_VAMPIRE.updateDevAddress(dev);
    }

    /**
    * @notice Changes the address where dev funds are distributed to
    * @param dev the new address
    */
    function changeDevFundAddress(address dev) external onlyOwner {
        devFundAddress = dev;
    }

    /**
    * @notice Changes the reward percentage distributed to reward pool
    * @param rewardPoolShare_ percentage using decimal base of 1000 ie: 10% = 100
    */
    function changeReward(uint256 rewardPoolShare_) external onlyOwner {
        rewardPoolShare = rewardPoolShare_;
    }
}