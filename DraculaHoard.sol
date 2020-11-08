// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DraculaToken.sol";

contract DraculaHoard is ERC20("DraculaHoard", "BLOOD"), Ownable {
    using SafeMath for uint256;
    IERC20 public dracula;
    uint256 public burnRate = 1;

    constructor(IERC20 _draculaToken) public {
        dracula = _draculaToken;
    }

    function setBurnRate(uint256 _burnRate) external onlyOwner {
        require(_burnRate <= 10, "Invalid burn rate value");
        burnRate = _burnRate;
    }

    /// @notice Return staked amount + rewards
    function balance(address account) public view returns (uint256) {
        uint256 totalShares = totalSupply();
        return (totalShares > 0) ? balanceOf(account).mul(dracula.balanceOf(address(this))).div(totalShares) : 0;
    }

    function stake(uint256 _amount) external {
        uint256 totalDracula = dracula.balanceOf(address(this));
        uint256 totalShares = totalSupply();
        if (totalShares == 0 || totalDracula == 0) {
            _mint(msg.sender, _amount);
        }
        else {
            uint256 what = _amount.mul(totalShares).div(totalDracula);
            _mint(msg.sender, what);
        }
        dracula.transferFrom(msg.sender, address(this), _amount);
    }

    function unstake(uint256 _share) external {
        uint256 totalShares = totalSupply();
        uint256 what = _share.mul(dracula.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        uint256 burnAmount = what.mul(burnRate).div(100);
        if (burnAmount > 0) {
            DraculaToken(address(dracula)).burn(burnAmount);
        }
        dracula.transfer(msg.sender, what.sub(burnAmount));
    }
}