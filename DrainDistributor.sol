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

interface IRewardPool {
    function fundPool(uint256 reward) external;
}

/**
* @title Receives rewards from MasterVampire via drain and redistributes to RewardPool
*/
contract DrainDistributor is Ownable {
    using SafeMath for uint256;
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IMasterVampire constant MASTER_VAMPIRE = IMasterVampire(0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099);

    uint256 public rewardPoolShare;
    address public rewardPool;
    address public lpController;

    /**
    * @notice Construct the contract
    * @param rewardPool_ address of the reward pool
    * @param lpController_ address of the LP controller
    */
    constructor(address rewardPool_, address lpController_) public {
        rewardPoolShare = 150;
        rewardPool = rewardPool_;
        lpController = lpController_;
    }

    /**
    * @notice Distributes drained rewards to RewardPool and DRC/ETH LP
    */
    function distribute() external {
        uint256 drainWethBalance = WETH.balanceOf(address(this));
        uint256 rewardPoolAmt = drainWethBalance.mul(rewardPoolShare).div(1000);
        uint256 lpAmt = drainWethBalance.sub(rewardPoolAmt);
        IRewardPool(rewardPool).fundPool(rewardPoolAmt);
        ILpController(lpController).addLiquidity(lpAmt);
    }

    /**
    * @notice Changes the reward percentage distributed to reward pool
    * @param rewardPoolShare_ percentage using decimal base of 1000 ie: 10% = 100
    */
    function changeReward(uint256 rewardPoolShare_) external onlyOwner {
        rewardPoolShare = rewardPoolShare_;
    }

    /**
    * @notice Changes the address of the LP controller
    * @param lpController_ the new address
    */
    function changeLp(address lpController_) external onlyOwner {
        lpController = lpController_;
    }
}
