// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.8.0;

interface ISettle {
    function settle() external;

    function hasSettled() external view returns (bool);

    function toBeSettled() external view returns (uint256[] memory);
}
