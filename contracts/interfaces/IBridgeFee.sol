// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface IBridgeFee {
    struct Fee {
        uint256 value;
        uint256 precisions;
    }

    function configure(
        address _feeAddress,
        Fee calldata _fee
    ) external;
}
