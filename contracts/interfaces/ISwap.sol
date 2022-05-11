// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.8.0;

interface ISwap {
    function token() external view returns (address);

    function currency() external view returns (address);

    function supply() external view returns (uint256);

    function investOf(address) external view returns (uint256);

    function totalRaised() external view returns (uint256);
}
