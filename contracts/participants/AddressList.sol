// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.8.0;

import "../interfaces/IParticipants.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract AddressList is IParticipants, Ownable {
    mapping(address => uint256) public whitelist;

    constructor(address[] memory list) {
        for (uint256 i = 0; i < list.length; i++) {
            whitelist[list[i]] = 1;
        }
    }

    function granted(address user) public view override returns (bool) {
        return whitelist[user] > 0;
    }

    function update(address u, uint256 amount) public onlyOwner {
        whitelist[u] = amount;
    }

    function set(address[] calldata list) public onlyOwner {
        for (uint256 i = 0; i < list.length; i++) {
            whitelist[list[i]] = 1;
        }
    }
}
