// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.8.0;

interface IInstantiate {
    function instantiate(bytes calldata initdata) external returns (address);
}
