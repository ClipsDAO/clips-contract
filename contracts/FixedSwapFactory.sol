// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./FixedSwap.sol";
import "./interfaces/IInstantiate.sol";

contract FixedSwapFactory is Ownable {
    using Address for address;

    constructor(address platform) {
        transferOwnership(platform);
    }

    function instantiate(bytes calldata initdata)
        external
        onlyOwner
        returns (address)
    {
        FixedSwap r = new FixedSwap();
        address(r).functionCall(initdata);
        r.transferOwnership(msg.sender);
        return address(r);
    }
}
