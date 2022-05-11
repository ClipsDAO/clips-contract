// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.8.0;

interface IFeeRate {
    function setFeeRate(uint256 f) external;

    function feeRate() external view returns (uint256);
}
