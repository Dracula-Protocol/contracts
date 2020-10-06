// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./libraries/UniswapV2Library.sol";
import "./Timelock.sol";
import "./VampireAdapter.sol";
import "./DraculaToken.sol";

contract MasterVampire is Ownable, Timelock {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using VampireAdapter for Victim;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        Victim victim;
        uint256 victimPoolId;
        uint256 rewardPerBlock;
        uint256 lastRewardBlock;
        uint256 accDrcPerShare;
        uint256 rewardDrainModifier;
        uint256 wethDrainModifier;
    }

//     (_                   _)
//      /\                 /\
//     / \'._   (\_/)   _.'/ \
//    /_.''._'--('.')--'_.''._\
//    | \_ / `;=/ " \=;` \ _/ |
//     \/ `\__|`\___/`|__/`  \/
//   jgs`      \(/|\)/       `
//              " ` "
    DraculaToken public dracula;
    IERC20 weth;
    IUniswapV2Pair drcWethPair;

    address public drainAddress;
    address public poolRewardUpdater;
    address public devAddress;
    uint256 public constant DEV_FEE = 8;
    uint256 public constant REWARD_START_BLOCK = 11008888; // Wed Oct 07 2020 13:28:00 UTC

    uint256 poolRewardLimiter;

    PoolInfo[] public poolInfo;

    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    modifier onlyDev() {
        require(devAddress == _msgSender(), "not dev");
        _;
    }

    modifier onlyRewardUpdater() {
        require(poolRewardUpdater == _msgSender(), "not reward updater");
        _;
    }

    constructor(
        DraculaToken _dracula,
        address _drainAddress
    ) public Timelock(msg.sender, 24 hours) {
        poolRewardLimiter = 300 ether;
        dracula = _dracula;
        drainAddress = _drainAddress;
        devAddress = msg.sender;
        weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        IUniswapV2Factory uniswapFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        drcWethPair = IUniswapV2Pair(uniswapFactory.getPair(address(weth), address(dracula)));
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(Victim _victim, uint256 _victimPoolId, uint256 _rewardPerBlock, uint256 _rewardDrainModifier, uint256 _wethDrainModifier) public onlyOwner {
        require(_rewardPerBlock <= poolRewardLimiter, "Pool reward per block is too high");
        poolInfo.push(PoolInfo({
            victim: _victim,
            victimPoolId: _victimPoolId,
            rewardPerBlock: _rewardPerBlock,
            rewardDrainModifier: _rewardDrainModifier,
            wethDrainModifier: _wethDrainModifier,
            lastRewardBlock: block.number < REWARD_START_BLOCK ? REWARD_START_BLOCK : block.number,
            accDrcPerShare: 0
        }));
    }

    function updatePoolRewardLimiter(uint256 _poolRewardLimiter) public onlyOwner {
        poolRewardLimiter = _poolRewardLimiter;
    }

    function updateRewardPerBlock(uint256 _pid, uint256 _rewardPerBlock) public onlyRewardUpdater {
        require(_rewardPerBlock <= poolRewardLimiter, "Pool reward per block is too high");
        updatePool(_pid);
        poolInfo[_pid].rewardPerBlock = _rewardPerBlock;
    }

    function updateRewardPerBlockMassive(uint256[] memory pids, uint256[] memory rewards) public onlyRewardUpdater {
        require(pids.length == rewards.length, "-__-");
        for (uint i = 0; i < pids.length; i++) {
            uint256 pid = pids[i];
            uint256 rewardPerBlock = rewards[i];
            require(rewardPerBlock <= poolRewardLimiter, "Pool reward per block is too high");
            updatePool(pid);
            poolInfo[pid].rewardPerBlock = rewardPerBlock;
        }
    }

    function updateVictimInfo(uint256 _pid, address _victim, uint256 _victimPoolId) public onlyOwner {
        poolInfo[_pid].victim = Victim(_victim);
        poolInfo[_pid].victimPoolId = _victimPoolId;
    }

    function updatePoolDrain(uint256 _pid, uint256 _rewardDrainModifier, uint256 _wethDrainModifier) public onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        pool.rewardDrainModifier = _rewardDrainModifier;
        pool.wethDrainModifier = _wethDrainModifier;
    }

    function updateDevAddress(address _devAddress) public onlyDev {
        devAddress = _devAddress;
    }

    function updateDrainAddress(address _drainAddress) public onlyOwner {
        drainAddress = _drainAddress;
    }

    function updateRewardUpdaterAddress(address _poolRewardUpdater) public onlyOwner {
        poolRewardUpdater = _poolRewardUpdater;
    }

    function pendingDrc(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accDrcPerShare = pool.accDrcPerShare;
        uint256 lpSupply = _pid == 0 ? drcWethPair.balanceOf(address(this)) : pool.victim.lockedAmount(pool.victimPoolId);
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 blocksToReward = block.number.sub(pool.lastRewardBlock);
            uint256 drcReward = blocksToReward.mul(pool.rewardPerBlock);
            accDrcPerShare = accDrcPerShare.add(drcReward.mul(1e12).div(lpSupply));
        }

        return user.amount.mul(accDrcPerShare).div(1e12).sub(user.rewardDebt);
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        uint256 lpSupply = _pid == 0 ? drcWethPair.balanceOf(address(this)) : pool.victim.lockedAmount(pool.victimPoolId);
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 blocksToReward = block.number.sub(pool.lastRewardBlock);
        uint256 drcReward = blocksToReward.mul(pool.rewardPerBlock);
        dracula.mint(devAddress, drcReward.mul(DEV_FEE).div(100));
        dracula.mint(address(this), drcReward);
        pool.accDrcPerShare = pool.accDrcPerShare.add(drcReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accDrcPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeDraculaTransfer(msg.sender, pending);
            }
        }

        if(_amount > 0) {
            if(_pid == 0) {
                IERC20(address(drcWethPair)).safeTransferFrom(address(msg.sender), address(this), _amount);
            } else {
                pool.victim.lockableToken(pool.victimPoolId).safeTransferFrom(address(msg.sender), address(this), _amount);
                pool.victim.deposit(pool.victimPoolId, _amount);
            }

            user.amount = user.amount.add(_amount);
        }

        user.rewardDebt = user.amount.mul(pool.accDrcPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }
    
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accDrcPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeDraculaTransfer(msg.sender, pending);
        }

        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            if(_pid == 0) {
                IERC20(address(drcWethPair)).safeTransfer(address(msg.sender), _amount);
            } else {
                pool.victim.withdraw(pool.victimPoolId, _amount);
                pool.victim.lockableToken(pool.victimPoolId).safeTransfer(address(msg.sender), _amount);
            }
        }

        user.rewardDebt = user.amount.mul(pool.accDrcPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if(_pid == 0) {
            IERC20(address(drcWethPair)).safeTransfer(address(msg.sender), user.amount);
        } else {
            pool.victim.withdraw(pool.victimPoolId, user.amount);
            pool.victim.lockableToken(pool.victimPoolId).safeTransfer(address(msg.sender), user.amount);
        }
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    function safeDraculaTransfer(address _to, uint256 _amount) internal {
        uint256 balance = dracula.balanceOf(address(this));
        if (_amount > balance) {
            dracula.transfer(_to, balance);
        } else {
            dracula.transfer(_to, _amount);
        }
    }
    
    function drain(uint256 _pid) public {
        require(_pid != 0, "Can't drain from myself");
        PoolInfo storage pool = poolInfo[_pid];
        Victim victim = pool.victim;
        uint256 victimPoolId = pool.victimPoolId;
        uint256 rewardDrainModifier = pool.rewardDrainModifier;
        victim.claimReward(victimPoolId);
        IERC20 rewardToken = victim.rewardToken();
        uint256 claimedReward = rewardToken.balanceOf(address(this));
        uint256 rewardDrainAmount = claimedReward.mul(rewardDrainModifier).div(1000);
        if(rewardDrainAmount > 0) {
            rewardToken.transfer(drainAddress, rewardDrainAmount);
            claimedReward = claimedReward.sub(rewardDrainAmount);
        }

        uint256 sellableAmount = victim.sellableRewardAmount();
        if(sellableAmount < claimedReward) { // victim is drained empty
            claimedReward = sellableAmount;
        }

        if(claimedReward == 0) {
            return;
        }

        uint256 wethDrainModifier = pool.wethDrainModifier;
        uint256 wethReward = victim.sellRewardForWeth(claimedReward, address(this));
        uint256 wethDrainAmount = wethReward.mul(wethDrainModifier).div(1000);
        if(wethDrainAmount > 0) {
            weth.transfer(drainAddress, wethDrainAmount);
            wethReward = wethReward.sub(wethDrainAmount);
        }

        address token0 = drcWethPair.token0();
        (uint reserve0, uint reserve1,) = drcWethPair.getReserves();
        (uint reserveInput, uint reserveOutput) = address(weth) == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        uint amountOutput = UniswapV2Library.getAmountOut(wethReward, reserveInput, reserveOutput);
        (uint amount0Out, uint amount1Out) = address(weth) == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));

        weth.transfer(address(drcWethPair), wethReward);
        drcWethPair.swap(amount0Out, amount1Out, address(this), new bytes(0));

        dracula.burn(amountOutput);
    }
}
