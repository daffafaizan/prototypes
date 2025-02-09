// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStoreFront {
    function purchase(suint prodId) external payable;
}
