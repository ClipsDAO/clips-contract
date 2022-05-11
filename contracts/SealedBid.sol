// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
//pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SealedBid is Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    uint256 public id;
    string public symbol;
    address public platform_addr;
    
    address public currency;
    address public underlying;
    uint public price;
    uint public time;
    uint public totalPurchasedCurrency;
    mapping (address => uint) public purchasedCurrencyOf;
    bool public completed;
    uint public totalSettledUnderlying;
    mapping (address => uint) public settledUnderlyingOf;
    uint public settleRate;
    uint public timeSettle;
    
    constructor(
        uint256 _id,
        string memory _symbol,
        address _platform,

        address _currency,
        address _underlying,
        uint256 _price,
        uint256 _time,
        uint256 _timeSettle
    ) public {
        id = _id;
        symbol = _symbol;
        platform_addr = _platform;

        currency = _currency;
        underlying = _underlying;
        price = _price;
        time = _time;
        timeSettle = _timeSettle;
        require(_timeSettle >= _time, 'timeSettle_ should >= time_');
    }

    function purchase(uint amount) external {
        require(now < time, 'expired');
        IERC20(currency).safeTransferFrom(msg.sender, address(this), amount);
        purchasedCurrencyOf[msg.sender] = purchasedCurrencyOf[msg.sender].add(amount);
        totalPurchasedCurrency = totalPurchasedCurrency.add(amount);
        emit Purchase(msg.sender, amount, totalPurchasedCurrency);
    }
    event Purchase(address indexed acct, uint amount, uint totalCurrency);
    
    function purchaseHT() public payable {
		require(address(currency) == address(0), 'should call purchase(uint amount) instead');
        require(now < time, 'expired');
        uint amount = msg.value;
        purchasedCurrencyOf[msg.sender] = purchasedCurrencyOf[msg.sender].add(amount);
        totalPurchasedCurrency = totalPurchasedCurrency.add(amount);
        emit Purchase(msg.sender, amount, totalPurchasedCurrency);
    }

    function totalSettleable() public view  returns (bool completed_, uint amount, uint volume, uint rate) {
        return settleable(address(0));
    }
    
    function settleable(address acct) public view returns (bool completed_, uint amount, uint volume, uint rate) {
        completed_ = completed;
        if(completed_) {
            rate = settleRate;
            if(settledUnderlyingOf[acct] > 0)
                return (completed_, 0, 0, rate);
        } else {
            uint totalCurrency = currency == address(0) ? address(this).balance : IERC20(currency).balanceOf(address(this));
            uint totalUnderlying = IERC20(underlying).balanceOf(address(this));
            if (currency == address(0)) {
                if(totalUnderlying.mul(price) < totalCurrency)
                    rate = totalUnderlying.mul(1e5).mul(price).div(totalCurrency);
                else
                    rate = 1e5;
            } else {
                if(totalUnderlying.mul(price) < totalCurrency.mul(1e10))
                    rate = totalUnderlying.mul(price).div(totalCurrency.mul(1e5));
                else
                    rate = 1e5;
            }
        }
        uint purchasedCurrency = acct == address(0) ? totalPurchasedCurrency : purchasedCurrencyOf[acct];
        uint settleAmount = purchasedCurrency.mul(rate);
        if (currency == address(0)) {
            amount = purchasedCurrency.div(1e10).sub(settleAmount.div(1e15));
            volume = settleAmount.div(price).div(1e18);
        } else {
            amount = purchasedCurrency.sub(settleAmount.div(1e5));
            volume = settleAmount.div(price).div(1e8);
        }
    }
    
    function settle() public {
        require(now >= timeSettle, "It's not time yet");
        require(settledUnderlyingOf[msg.sender] == 0, 'settled already');
        (bool completed_, uint amount, uint volume, uint rate) = settleable(msg.sender);
        if(!completed_) {
            completed = true;
            settleRate = rate;
        }
        settledUnderlyingOf[msg.sender] = volume;
        totalSettledUnderlying = totalSettledUnderlying.add(volume);
        if(currency == address(0))
            msg.sender.transfer(amount.mul(1e10));
        else
            IERC20(currency).safeTransfer(msg.sender, amount);
        IERC20(underlying).safeTransfer(msg.sender, volume.mul(1e13));
        emit Settle(msg.sender, amount, volume, rate);
    }
    event Settle(address indexed acct, uint amount, uint volume, uint rate);
    
    function withdrawable() public view returns (uint amt, uint vol) {
        if(!completed)
            return (0, 0);
        amt = currency == address(0) ? address(this).balance : IERC20(currency).balanceOf(address(this));
        amt = amt.add(totalSettledUnderlying.mul(price).div(settleRate).mul(uint(1e18).sub(settleRate)).div(1e18)).sub(totalPurchasedCurrency.mul(uint(1e18).sub(settleRate)).div(1e18));
        vol = IERC20(underlying).balanceOf(address(this)).add(totalSettledUnderlying).sub(totalPurchasedCurrency.mul(settleRate).div(price));
    }
    
    function withdraw(address payable to, uint amount, uint volume) external onlyOwner {
        require(completed, "uncompleted");
        (uint amt, uint vol) = withdrawable();
        amount = Math.min(amount, amt);
        volume = Math.min(volume, vol);
        if(currency == address(0))
            to.transfer(amount);
        else
            IERC20(currency).safeTransfer(to, amount);
        IERC20(underlying).safeTransfer(to, volume);
        emit Withdrawn(to, amount, volume);
    }
    event Withdrawn(address to, uint amount, uint volume);
    
    /// @notice This method can be used by the owner to extract mistakenly
    ///  sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    function rescueTokens(address _token, address _dst) public onlyOwner {
        uint balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(_dst, balance);
    }
    
    function withdrawToken(address _dst) external onlyOwner {
        rescueTokens(address(underlying), _dst);
    }

    function withdrawToken() external onlyOwner {
        rescueTokens(address(underlying), msg.sender);
    }
    
    function withdrawHT(address payable _dst) external onlyOwner {
        _dst.transfer(address(this).balance);
    }
    
    function withdrawHT() external onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    receive() external payable{
        if(msg.value > 0)
            purchaseHT();
        else
            settle();
    }
    
    fallback() external {
        settle();
    }
}
