/*
 * SPDX-License-Identifier: UNLICENSED
 *
 * AMM that hides the price of quote asset until it's above some threshold.
 *
 */
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "solmate/utils/ReentrancyGuard.sol";

import "./ViolinCoin.sol";

/*//////////////////////////////////////////////////////////////
//                         ViolinAMM Contract
//////////////////////////////////////////////////////////////*/

contract ViolinAMM is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
    //                        TOKEN STORAGE
    //////////////////////////////////////////////////////////////*/
    ViolinCoin public baseAsset;
    ViolinCoin public quoteAsset;

    /*//////////////////////////////////////////////////////////////
    //                        AMM STORAGE
    //////////////////////////////////////////////////////////////*/
    saddress adminAddress;

    suint256 wad;
    suint256 priceReveal;

    suint256 baseReserve;
    suint256 quoteReserve;

    mapping(saddress => sbool) hasListened;
    mapping(saddress => suint256) lastListenedTimestamp;

    /*//////////////////////////////////////////////////////////////
    //                        EVENTS
    //////////////////////////////////////////////////////////////*/

    // Listening event should be an encrypted event
    /// @notice Emitted when a user puts a request to listen
    event Listening(address indexed user);

    /// @notice Emitted when a swap is executed by the user
    event SwapExecuted(address indexed user);

    /*//////////////////////////////////////////////////////////////
    //                        MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /*
     * Only listener can call this function
     */
    modifier onlyViolinListener() {
        require(hasListened[saddress(msg.sender)], "You are not the listener");
        _;
    }

    /*
     * Listen to the music
     */
    function listen() external {
        hasListened[saddress(msg.sender)] = sbool(true);
        lastListenedTimestamp[saddress(msg.sender)] = suint256(block.timestamp);
        emit Listening(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        ViolinCoin _baseAsset,
        ViolinCoin _quoteAsset,
        uint256 _wad,
        uint256 _priceReveal,
        address _adminAddress
    ) {
        baseAsset = _baseAsset;
        quoteAsset = _quoteAsset;

        adminAddress = saddress(_adminAddress);

        // Stored as suint256 for convenience. Not actually shielded bc it's a
        // transparent parameter in the constructor
        wad = suint256(_wad);
        priceReveal = suint256(_priceReveal);
    }
    /*//////////////////////////////////////////////////////////////
                            AMM LOGIC
    //////////////////////////////////////////////////////////////*/

    /*
     * Add liquidity to pool. No LP rewards in this implementation.
     */
    function addLiquidity(suint256 baseAmount, suint256 quoteAmount) external {
        baseReserve = baseReserve + baseAmount;
        quoteReserve = quoteReserve + quoteAmount;

        saddress ssender = saddress(msg.sender);
        saddress sthis = saddress(address(this));
        baseAsset.transferFrom(ssender, sthis, baseAmount);
        quoteAsset.transferFrom(ssender, sthis, quoteAmount);
    }

    /*
     * Wrapper around swap so calldata for trade looks the same regardless of
     * direction.
     */
    function swap(suint256 baseIn, suint256 quoteIn) public nonReentrant onlyViolinListener {
        // After listening to the music, the user can call this function to swap the assets
        // Price gets revealed here
        require(
            suint256(block.timestamp) >= suint256(lastListenedTimestamp[saddress(msg.sender)]) + suint256(10 seconds),
            "Must wait 10 seconds before calling swap"
        );

        suint256 baseOut;
        suint256 quoteOut;

        (baseOut, baseReserve, quoteReserve) = _swap(baseAsset, quoteAsset, baseReserve, quoteReserve, baseIn);
        (quoteOut, quoteReserve, baseReserve) = _swap(quoteAsset, baseAsset, quoteReserve, baseReserve, quoteIn);

        emit SwapExecuted(msg.sender);
        hasListened[saddress(msg.sender)] = sbool(false);
    }

    /*
     * Swap for cfAMM. No fees.
     */
    function _swap(ViolinCoin tokenIn, ViolinCoin tokenOut, suint256 reserveIn, suint256 reserveOut, suint256 amountIn)
        internal
        returns (suint256 amountOut, suint256 reserveInNew, suint256 reserveOutNew)
    {
        suint256 numerator = mulDivDown(reserveOut, amountIn, wad);
        suint256 denominator = reserveIn + amountIn;
        amountOut = mulDivDown(numerator, wad, denominator);

        reserveInNew = reserveIn + amountIn;
        reserveOutNew = reserveOut - amountOut;

        saddress ssender = saddress(msg.sender);
        saddress sthis = saddress(address(this));
        tokenIn.transferFrom(ssender, sthis, amountIn);
        tokenOut.transfer(ssender, amountOut);
    }

    /*
     * Only returns price if it's above priceReveal threshold.
     */
    function getPriceGated() external view requirePriceSufficient returns (uint256 price) {
        return uint256(_computePrice());
    }

    /*
     * Bypasses priceReveal threshold. For testing purposes.
     */
    function getPrice() external onlyViolinListener returns (uint256 price) {
        hasListened[saddress(msg.sender)] = sbool(false);
        return uint256(_computePrice());
    }

    /*
     * Compute price of quote asset.
     */
    function _computePrice() internal view returns (suint256 price) {
        price = mulDivDown(baseReserve, wad, quoteReserve);
    }

    /*
     * For wad math.
     */
    function mulDivDown(suint256 x, suint256 y, suint256 denominator) internal pure returns (suint256 z) {
        require(
            denominator != suint256(0) && (y == suint256(0) || x <= suint256(type(uint256).max) / y),
            "Overflow or division by zero"
        );
        z = (x * y) / denominator;
    }

    /*
     * Assert price of quote asset above priceReveal threshold.
     */
    modifier requirePriceSufficient() {
        require(_computePrice() >= priceReveal, "Price of quote asset is not high enough.");
        _;
    }

    /*//////////////////////////////////////////////////////////////
    //                        GETTERS
    //////////////////////////////////////////////////////////////*/

    /*
     * Get the base reserve
     */
    function getBaseReserve() external view returns (uint256) {
        return uint256(baseReserve);
    }

    /*
     * Get the quote reserve
     */
    function getQuoteReserve() external view returns (uint256) {
        return uint256(quoteReserve);
    }
}
