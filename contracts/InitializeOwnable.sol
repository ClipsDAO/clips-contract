//SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.8.0;

abstract contract InitializeOwnable {
    address internal _owner;

    modifier onlyOwner() {
        require(msg.sender == _owner, "caller is not owner");
        _;
    }

    function setOwner(address _who) public onlyOwner {
        _owner = _who;
    }

    function initialize(address _who) public virtual {
        _owner = _who;
    }

    function owner() public view returns (address) {
        return _owner;
    }
}
