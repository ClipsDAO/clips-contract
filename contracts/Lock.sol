// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.7.0;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct Locked {
    uint256 totalAmount;
    uint256 shares;
    uint256 left;
    uint256 lastClaim;
}

contract Lock is Context, Ownable {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public nextRelease;
    uint256 public interval;

    mapping(address => Locked) public vesters;

    uint256 public vestersCount;
    address[] public vestersSlice;

    address public treasure;

    constructor(address _treasure, uint256 _interval) public {
        treasure = _treasure;
        interval = _interval;
    }

    function setup(
        address u,
        uint256 granted_amount,
        uint256 locked_amount,
        uint256 shares
    ) public onlyOwner {
        vesters[u] = Locked({
            totalAmount: locked_amount,
            shares: shares,
            left: shares,
            lastClaim: 0
        });
        vestersSlice.push(u);
        vestersCount++;
    }

    function go() public onlyOwner {
        for (uint256 i = 0; i < vestersCount; i++) {
            Locked storage v = vesters[vestersSlice[i]];
            v.lastClaim = block.timestamp;
        }

        nextRelease = block.timestamp + interval;
    }

    function balanceOf(address who) public view returns (uint256) {
        Locked storage v = vesters[who];
        if (v.left == 0) {
            return 0;
        }
        return v.totalAmount.div(v.shares).mul(v.left);
    }

    function canClaimOf(address who) public view returns (uint256) {
        Locked storage v = vesters[who];
        if (v.lastClaim == 0 || v.left == 0) {
            return 0;
        }
        uint256 shareToRelease = _shareToRelease(v.lastClaim, v.left);
        return v.totalAmount.div(v.shares).mul(shareToRelease);
    }

    function _shareToRelease(uint256 lastClaim, uint256 sharesLeft)
        internal
        view
        returns (uint256)
    {
        uint256 elapsed = block.timestamp.sub(lastClaim);
        uint256 shareToRelease = elapsed.div(interval);
        if (shareToRelease == 0) {
            return 0;
        }
        if (shareToRelease > sharesLeft) {
            shareToRelease = sharesLeft;
        }
        return shareToRelease;
    }

    function canClaim() public view returns (uint256) {
        Locked storage v = vesters[msg.sender];
        if (v.left == 0 || v.lastClaim == 0) {
            return 0;
        }
        uint256 shareToRelease = _shareToRelease(v.lastClaim, v.left);
        return v.totalAmount.div(v.shares).mul(shareToRelease);
    }

    function claim() public {
        Locked storage v = vesters[msg.sender];
        if (v.left == 0 || v.lastClaim == 0) {
            revert("not ready");
        }
        uint256 shareToRelease = _shareToRelease(v.lastClaim, v.left);
        if (shareToRelease == 0) {
            revert("not ready");
        }
        uint256 releaseAmount = v.totalAmount.div(v.shares).mul(shareToRelease);
        IERC20(treasure).safeTransfer(msg.sender, releaseAmount);
        if (v.left == shareToRelease) {
            delete vesters[msg.sender];
        } else {
            v.left = v.left.sub(shareToRelease);
            v.lastClaim = block.timestamp;
        }
    }
}
