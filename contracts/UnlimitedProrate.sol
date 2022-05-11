// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.8.0;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IDecimals.sol";
import "./interfaces/IParticipants.sol";
import "./interfaces/ISwap.sol";
import "./interfaces/ISettle.sol";
import "./interfaces/IClaim.sol";
import "./interfaces/IID.sol";

contract UnlimitedProrate is Ownable, ISwap, ISettle, IClaim, IID {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public override id;

    address public override currency;
    address public override token;
    uint256 public override supply;

    uint256 public ratio;
    uint256 public bidBegin;
    uint256 public bidEnd;
    uint256 public quotaLimits;
    uint256 public override totalRaised;
    uint256 public totalClaimed;
    address public participants;
    address payable public founder;
    bool public override hasSettled;

    uint256 public raisingTarget;

    uint256 public tokenScales;
    uint256 public currencyScales;

    uint256 constant RatioScales = 1e8;

    mapping(address => uint256) public override investOf;
    mapping(address => uint256) public claimedInvestOf;
    mapping(address => uint256) public claimedOf;

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
        address _participants
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
            .mul(_ratio)
            .mul(currencyScales)
            .div(tokenScales)
            .div(RatioScales);

        feeRate = 15;
    }

    function setFeeRate(uint256 _f) public onlyOwner {
        feeRate = _f;
    }

    function isOver() public view returns (bool) {
        return block.timestamp >= bidEnd;
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

        if (participants != address(0)) {
            require(
                IParticipants(participants).granted(msg.sender),
                "not granted"
            );
        }

        if (currency == address(0)) {
            require(amount == 0, "invalid amount");
            amount = msg.value;
        }

        if (quotaLimits > 0) {
            require(amount <= quotaLimits, "too much");
            amount = Math.min(amount, quotaLimits - investOf[msg.sender]);
        }
        require(amount > 0, "no quota");

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

        investOf[msg.sender] += amount;
        totalRaised += amount;
    }

    function claim() public override {
        require(isOver(), "just a sec");

        uint256 investAmount =
            investOf[msg.sender] - claimedInvestOf[msg.sender];
        require(investAmount > 0, "you have no investment");

        (uint256 canClaim, uint256 cost) = _calculateRewards(msg.sender);
        require(cost <= investAmount, "cost & invest go south");
        uint256 investRemains = investAmount.sub(cost);

        IERC20(token).safeTransfer(msg.sender, canClaim);

        claimedOf[msg.sender] += canClaim;
        totalClaimed += canClaim;
        claimedInvestOf[msg.sender] += cost;

        if (investRemains > 0) {
            if (currency == address(0)) {
                uint256 balance = payable(address(this)).balance;
                if (investRemains > balance) {
                    investRemains = balance;
                }
                payable(msg.sender).transfer(investRemains);
            } else {
                uint256 balance = IERC20(currency).balanceOf(address(this));
                if (investRemains > balance) {
                    investRemains = balance;
                }
                IERC20(currency).transfer(msg.sender, investRemains);
            }
        }
    }

    function toBeClaimed(address user)
        public
        view
        override
        returns (uint256[] memory)
    {
        require(isOver(), "just a sec");
        uint256 investAmount = investOf[user] - claimedInvestOf[user];
        (uint256 tokenAmount, uint256 cost) = _calculateRewards(user);
        uint256 investmentReturn = investAmount - cost;
        uint256[] memory ret = new uint256[](2);
        ret[0] = tokenAmount;
        ret[1] = investmentReturn;
        return ret;
    }

    function _calculateRewards(address user)
        internal
        view
        returns (uint256 _tokenAmount, uint256 _cost)
    {
        uint256 investAmount = investOf[user] - claimedInvestOf[user];
        if (investAmount == 0) {
            return (0, 0);
        }

        uint256 canClaim = 0;
        uint256 cost = investAmount;

        if (raisingTarget < totalRaised) {
            canClaim = supply.mul(investAmount).div(totalRaised);
            cost = canClaim.mul(ratio).mul(currencyScales).div(RatioScales).div(
                tokenScales
            );
            uint256 shouldPay =
                raisingTarget.mul(investAmount).div(totalRaised);
            if (cost < shouldPay) {
                cost = shouldPay;
            }
        } else {
            canClaim = investAmount
                .mul(RatioScales)
                .mul(tokenScales)
                .div(currencyScales)
                .div(ratio);
        }

        uint256 _tokenRemains = IERC20(token).balanceOf(address(this));
        if (canClaim > _tokenRemains) {
            canClaim = _tokenRemains;
        }

        return (canClaim, cost);
    }

    // function emergencyExit() public {
    // }

    function settle() public override onlyFounder(msg.sender) {
        require(isOver(), "not over yet");
        require(!hasSettled, "already setteld");
        hasSettled = true;

        uint256 settlements = 0;
        uint256 supplyRemains = supply;
        if (totalRaised >= raisingTarget) {
            settlements = raisingTarget;
            supplyRemains = 0;
        } else {
            if (totalRaised > 0) {
                settlements = totalRaised;
                supplyRemains = supply.sub(
                    totalRaised
                        .mul(RatioScales)
                        .mul(tokenScales)
                        .div(ratio)
                        .div(currencyScales)
                );
            }
        }

        if (settlements > 0) {
            uint256 fee = feeRate > 0 ? settlements.mul(feeRate).div(1000) : 0;
            if (currency == address(0)) {
                if (settlements > payable(address(this)).balance) {
                    settlements = payable(address(this)).balance;
                }
                founder.call{value: settlements - fee}("");
                if (fee > 0) {
                    owner().call{value: fee}("");
                }
            } else {
                if (settlements > IERC20(currency).balanceOf(address(this))) {
                    settlements = IERC20(currency).balanceOf(address(this));
                }
                if (fee > 0) {
                    IERC20(currency).transfer(owner(), fee);
                }
                IERC20(currency).transfer(founder, settlements - fee);
            }
        }

        if (supplyRemains > 0) {
            IERC20(token).transfer(founder, supplyRemains);
        }
    }

    function toBeSettled() external view override returns (uint256[] memory) {
        uint256 settlements = 0;
        uint256 supplyRemains = 0;
        if (totalRaised >= raisingTarget) {
            settlements = raisingTarget;
        } else {
            settlements = totalRaised;
            supplyRemains = supply.sub(
                totalRaised.mul(RatioScales).mul(tokenScales).div(ratio).div(
                    currencyScales
                )
            );
        }
        uint256 fee = feeRate > 0 ? settlements.mul(feeRate).div(1000) : 0;
        uint256[] memory ret = new uint256[](2);
        ret[0] = settlements - fee;
        ret[1] = supplyRemains;
        return ret;
    }

    function hasClaimed(address addr) external view override returns (bool) {
        return claimedOf[addr] > 0;
    }
}
