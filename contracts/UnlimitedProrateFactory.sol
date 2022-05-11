// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./UnlimitedProrate.sol";
import "./interfaces/IInstantiate.sol";

contract UnlimitedProrateFactory is Ownable {
    using Address for address;

    constructor(address platform) {
        transferOwnership(platform);
    }

    function instantiate(bytes calldata initdata)
        external
        onlyOwner
        returns (address)
    {
        UnlimitedProrate r = new UnlimitedProrate();
        address(r).functionCall(initdata);
        r.transferOwnership(msg.sender);
        return address(r);
    }
}
