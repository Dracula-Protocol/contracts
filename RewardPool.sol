// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./DraculaToken.sol";

abstract contract IRewardDistributor is Ownable {
    address rewardDistributor;

    constructor(address _rewardDistributor) public {
        rewardDistributor = _rewardDistributor;
    }

    function notifyRewardAmount(uint256 reward) external virtual;

    modifier onlyRewardDistributor() {
        require(_msgSender() == rewardDistributor, "Caller is not reward distribution");
        _;
    }

    function setRewardDistributor(address _rewardDistributor)
        external
        onlyOwner
    {
        rewardDistributor = _rewardDistributor;
    }
}

contract LPTokenWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for DraculaToken;

    DraculaToken public lpToken;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        lpToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public virtual {
        require(_balances[msg.sender] >= amount, "withdraw: insufficient balance");
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        lpToken.safeTransfer(msg.sender, amount);
    }
}


/// @title A reward pool that does not mint
/// @dev The rewards should be first transferred to this pool, then get "notified" by calling `notifyRewardAmount`.
///      Only the reward distributor can notify.
contract RewardPool is LPTokenWrapper, IRewardDistributor, ReentrancyGuard {

    using Address for address;

    IERC20 public rewardToken;
    uint256 public duration;

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public burnRate = 1; // default 1%
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardDenied(address indexed user, uint256 reward);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(
        address _rewardToken,
        address _lpToken,
        uint256 _duration,
        address _rewardDistributor) public
    IRewardDistributor(_rewardDistributor)
    {
        rewardToken = IERC20(_rewardToken);
        lpToken = DraculaToken(_lpToken);
        duration = _duration;
    }

    function setBurnRate(uint8 _burnRate) external onlyOwner {
        require(_burnRate >= 0 && _burnRate <= 10, "Invalid burn rate value");
        burnRate = _burnRate;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    /// @notice Calculate the earned rewards for an account
    /// @return amount earned by specified account
    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    /// @notice Stake specified amount
    /// @dev visibility is public as overriding LPTokenWrapper's stake() function
    function stake(uint256 amount) public nonReentrant updateReward(msg.sender) override {
        require(amount > 0, "Cannot stake 0");
        super.stake(amount);
        emit Staked(msg.sender, amount);
    }

    /// @notice Withdraw specified amount
    /// @dev A configurable percentage is burnt on withdrawal
    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) override {
        require(amount > 0, "Cannot withdraw 0");
        uint256 amount_send = amount;

        if (burnRate > 0) {
            uint256 amount_burn = amount.mul(burnRate).div(100);
            amount_send = amount.sub(amount_burn);
            require(amount == amount_send + amount_burn, "Burn value invalid");
            lpToken.burn(amount_burn);
        }

        super.withdraw(amount_send);
        emit Withdrawn(msg.sender, amount_send);
    }

    /// @notice Withdraw everything and collect rewards
    function exit() external nonReentrant {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    /// @notice A push mechanism for accounts that have not claimed their rewards for a long time.
    /// @dev The implementation is semantically analogous to getReward(), but uses a push pattern
    /// instead of pull pattern.
    function pushReward(address recipient) public nonReentrant updateReward(recipient) {
        uint256 reward = earned(recipient);
        if (reward > 0) {
            rewards[recipient] = 0;
            rewardToken.safeTransfer(recipient, reward);
            emit RewardPaid(recipient, reward);
        }
    }

    /// @notice Claims reward for the sender account
    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /// @dev Should be called by external mechanism when reward funds are sent to this contract
    function notifyRewardAmount(uint256 reward)
        external
        override
        nonReentrant
        onlyRewardDistributor
        updateReward(address(0))
    {
        // overflow fix according to https://sips.synthetix.io/sips/sip-77
        require(reward < uint(-1) / 1e18, "the notified reward cannot invoke multiplication overflow");

        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(duration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(duration);
        }
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(duration);
        emit RewardAdded(reward);
    }
}