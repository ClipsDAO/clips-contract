// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.8.0;

interface IClaim {
    function claim() external;

    function hasClaimed(address) external view returns (bool);

    function toBeClaimed(address) external view returns (uint256[] memory);
}
