// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.8.0;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IDecimals.sol";
import "./interfaces/IParticipants.sol";
import "./interfaces/ISwap.sol";
import "./interfaces/ISettle.sol";
import "./interfaces/IClaim.sol";
import "./interfaces/IID.sol";

contract FixedSwap is Ownable, ISwap, ISettle, IClaim, IID {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; //using WETH temporarily

    uint256 public override id;

    address public override currency;
    address public override token;
    uint256 public override supply;

    uint256 public ratio;
    uint256 public bidBegin;
    uint256 public bidEnd;
    uint256 public quotaLimits;
    uint256 public sold;
    uint256 public totalClaimed;
    uint256 public raisingTarget;
    uint256 public override totalRaised;
    address public participants;
    uint256 public clipsTh;
    address payable public founder;
    bool public override hasSettled;

    mapping(address => uint256) public override investOf;
    mapping(address => uint256) _toBeClaimed;

    uint256 public tokenScales;
    uint256 public currencyScales;

    uint256 constant RatioScales = 1e8;

    uint256 public feeRate;

    modifier onlyFounder(address u) {
        require(u == founder, "only founder");
        _;
    }

    function initialize(
        address payable _founder,
        uint256 _id,
        address _currency,
        address _token,
        uint256 _ratio,
        uint256 _begin,
        uint256 _end,
        uint256 _quota,
        uint256 _supply,
        address _participants,
        uint256 _clipsTh
    ) public onlyOwner {
        id = _id;
        currency = _currency;
        token = _token;
        ratio = _ratio;
        bidBegin = _begin;
        bidEnd = _end;
        quotaLimits = _quota;
        supply = _supply;
        founder = _founder;
        participants = _participants;
        clipsTh = _clipsTh;

        uint8 currencyDecimals;
        uint8 tokenDecimals = IDecimals(token).decimals();
        if (currency == address(0)) {
            currencyDecimals = 18;
        } else {
            currencyDecimals = IDecimals(currency).decimals();
        }

        tokenScales = 10**tokenDecimals;
        currencyScales = 10**currencyDecimals;

        raisingTarget = supply
            .mul(ratio)
            .mul(currencyScales)
            .div(RatioScales)
            .div(tokenScales);

        feeRate = 15;
    }

    function setFeeRate(uint256 _f) public onlyOwner {
        feeRate = _f;
    }

    function isOver() public view returns (bool) {
        return block.timestamp >= bidEnd || sold == supply;
    }

    /// @param amount is the investment amount when using ERC20
    ///                       should be 0 when the investment is ETH
    function invest(uint256 amount) external payable {
        require(block.timestamp >= bidBegin, "it's not time yet");
        require(block.timestamp < bidEnd, "it's over");
        require(
            (currency != address(0) && msg.value == 0) ||
                (currency == address(0) && msg.value > 0),
            "unsupported capital"
        );

        //   if (participants != address(0)) {
        if (clipsTh > 0) {
            require(
                IERC20(WETH).balanceOf(participants) >= clipsTh,
                "not enough token holder."
            );
            //require(
            //    IParticipants(participants).granted(msg.sender),
            //    "not granted"
            //);
        }

        if (currency == address(0)) {
            require(amount == 0, "invalid amount");
            amount = msg.value;
        }

        if (quotaLimits > 0) {
            require(amount <= quotaLimits, "too much");
            amount = Math.min(amount, quotaLimits - investOf[msg.sender]);
        }
        amount = Math.min(amount, raisingTarget - totalRaised);
        require(amount > 0, "no quota");
        investOf[msg.sender] += amount;
        totalRaised += amount;

        if (currency == address(0)) {
            if (msg.value - amount > 0) {
                // send back the rest
                payable(msg.sender).transfer(msg.value - amount);
            }
        } else {
            // only take amount from user
            IERC20(currency).safeTransferFrom(
                msg.sender,
                address(this),
                amount
            );
        }

        uint256 amountSold =
            amount.mul(tokenScales).mul(RatioScales).div(currencyScales).div(
                ratio
            );
        _toBeClaimed[msg.sender] += amountSold;
        require(sold + amountSold <= supply, "not enough to sell");
        sold += amountSold;
    }

    function claim() public override {
        require(supply - sold < 100 || block.timestamp >= bidEnd, "just a sec");
        uint256 canClaim = _toBeClaimed[msg.sender];
        require(canClaim > 0, "nothing left");

        totalClaimed = totalClaimed.add(canClaim);
        IERC20(token).safeTransfer(msg.sender, canClaim);
        _toBeClaimed[msg.sender] = 0;
        delete (_toBeClaimed[msg.sender]);
    }

    // function emergencyExit() public {
    //     require(_toBeClaimed[msg.sender] > 0, "nothing to lose");
    //     uint256 tokenAmount = _toBeClaimed[msg.sender];
    //     delete (_toBeClaimed[msg.sender]);
    //     sold -= tokenAmount;
    //     require(sold >= 0, "something wrong with sold");

    //     uint256 toReturn =
    //         tokenAmount.mul(currencyScales).mul(RatioScales).div(ratio).div(
    //             tokenScales
    //         );
    //     IERC20(token).safeTransfer(msg.sender, toReturn);
    // }

    function settle() public override onlyFounder(msg.sender) {
        require(isOver(), "not over yet");
        require(!hasSettled, "already settled");
        hasSettled = true;

        if (totalRaised > 0) {
            uint256 fee = feeRate > 0 ? totalRaised.mul(feeRate).div(1000) : 0;
            if (currency == address(0)) {
                if (fee > 0) {
                    owner().call{value: fee}("");
                }
                founder.call{value: totalRaised - fee}("");
            } else {
                IERC20(currency).transfer(founder, totalRaised - fee);
                if (fee > 0) {
                    IERC20(currency).transfer(owner(), fee);
                }
            }
        }

        if (supply - sold > 0) {
            IERC20(token).transfer(founder, supply - sold);
        }
    }

    function toBeSettled() external view override returns (uint256[] memory) {
        uint256 fee = feeRate > 0 ? totalRaised.mul(feeRate).div(1000) : 0;
        uint256[] memory ret = new uint256[](2);
        ret[0] = totalRaised - fee;
        ret[1] = supply - sold;
        return ret;
    }

    function hasClaimed(address addr) external view override returns (bool) {
        return investOf[addr] > 0 && _toBeClaimed[addr] == 0;
    }

    function toBeClaimed(address addr)
        external
        view
        override
        returns (uint256[] memory)
    {
        uint256[] memory ret = new uint256[](1);
        ret[0] = _toBeClaimed[addr];
        return ret;
    }
}
