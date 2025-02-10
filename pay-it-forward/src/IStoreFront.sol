// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title StoreFront Interface
/// @dev This interface defines the function required for purchasing a product in a businesses storefront system.
interface IStoreFront {
    /**
     * @notice Allows a business to set up their own personal storefront
     * @dev This function accepts a payment to complete the purchase of a product and requires the product ID as input to identify which product to purchase.
     * @param prodId The ID of the product to be purchased.
     */
    function purchase(suint prodId) external payable;
}