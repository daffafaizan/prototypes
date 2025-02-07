// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import "../src/ViolinAMM.sol";
import {Test, console} from "forge-std/Test.sol";

/*//////////////////////////////////////////////////////////////
//                    ViolinAMMTest Contract
//////////////////////////////////////////////////////////////*/
contract ViolinAMMTest is Test {
    /*//////////////////////////////////////////////////////////////
    //                        AMM STORAGE
    //////////////////////////////////////////////////////////////*/
    ViolinAMM public amm;

    /*//////////////////////////////////////////////////////////////
    //                        TOKEN STORAGE
    //////////////////////////////////////////////////////////////*/
    ViolinCoin baseAsset;
    ViolinCoin quoteAsset;

    /*//////////////////////////////////////////////////////////////
    //                        AMM STORAGE
    //////////////////////////////////////////////////////////////*/
    address testAdmin = address(0xabcd);

    uint256 constant WAD = 1e18;
    uint8 constant WAD_ZEROS = 18;

    address constant SWAPPER1_ADDR = address(123);
    address constant SWAPPER2_ADDR = address(456);

    address constant NON_LISTENER_ADDR = address(789);

    /*//////////////////////////////////////////////////////////////
    //                        SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public {
        baseAsset = new ViolinCoin(address(this), "Circle", "USDC", 18);
        quoteAsset = new ViolinCoin(address(this), "Chainlink", "LINK", 18);

        // Start with pool price 1 LINK = 25 USDC
        amm = new ViolinAMM(ViolinCoin(address(baseAsset)), ViolinCoin(address(quoteAsset)), WAD, 25 * WAD, testAdmin);
        baseAsset.mint(saddress(address(this)), suint256(200000 * WAD));
        quoteAsset.mint(saddress(address(this)), suint256(10000 * WAD));
        baseAsset.approve(saddress(address(amm)), suint256(200000 * WAD));
        quoteAsset.approve(saddress(address(amm)), suint256(10000 * WAD));
        amm.addLiquidity(suint256(200000 * WAD), suint256(10000 * WAD));

        // Two swappers start with 50k units of each, LINK and USDC
        baseAsset.mint(saddress(SWAPPER1_ADDR), suint256(50000 * WAD));
        quoteAsset.mint(saddress(SWAPPER1_ADDR), suint256(50000 * WAD));
        baseAsset.mint(saddress(SWAPPER2_ADDR), suint256(50000 * WAD));
        quoteAsset.mint(saddress(SWAPPER2_ADDR), suint256(50000 * WAD));

        // Another address that starts with 50k units of each, LINK and USDC
        baseAsset.mint(saddress(NON_LISTENER_ADDR), suint256(50000 * WAD));
        quoteAsset.mint(saddress(NON_LISTENER_ADDR), suint256(50000 * WAD));

        // Request violin access for test accounts
        vm.startPrank(SWAPPER1_ADDR);
        amm.listen();
        vm.stopPrank();

        vm.startPrank(SWAPPER2_ADDR);
        amm.listen();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
    //                        TEST CASES 
    //////////////////////////////////////////////////////////////*/
    /*
     * Test case for price going up after swap
     */
    function test_PriceUp() public {
        vm.startPrank(SWAPPER1_ADDR);
        amm.listen();
        vm.warp(block.timestamp + 11);

        uint256 priceT0 = amm.getPrice();
        uint256 swapperBaseT0 = baseAsset.balanceOf();
        uint256 swapperQuoteT0 = quoteAsset.balanceOf();

        baseAsset.approve(saddress(address(amm)), suint256(30000 * WAD));
        amm.listen();
        vm.warp(block.timestamp + 11);
        amm.swap(suint256(30000 * WAD), suint256(0));

        amm.listen();
        vm.warp(block.timestamp + 11);
        assertLt(priceT0, amm.getPrice());
        assertGt(swapperBaseT0, baseAsset.balanceOf());
        assertLt(swapperQuoteT0, quoteAsset.balanceOf());

        vm.stopPrank();
    }

    /*
     * Test case for price going down after swap. 
     */
    function test_PriceNetDown() public {
        vm.startPrank(SWAPPER1_ADDR);
        vm.warp(block.timestamp + 11);
        uint256 priceT0 = amm.getPrice();
        baseAsset.approve(saddress(address(amm)), suint256(5000 * WAD));
        amm.listen();
        vm.warp(block.timestamp + 11);
        amm.swap(suint256(5000 * WAD), suint256(0));
        vm.stopPrank();

        vm.startPrank(SWAPPER2_ADDR);
        vm.warp(block.timestamp + 11);
        quoteAsset.approve(saddress(address(amm)), suint256(5000 * WAD));
        amm.swap(suint256(0), suint256(5000 * WAD));

        amm.listen();
        vm.warp(block.timestamp + 11);
        assertGt(priceT0, amm.getPrice());

        vm.stopPrank();
    }

    /*
     * Test case for revealing price. If the price is not above the threshold,
     * getPriceGated should revert.
     */
    function test_PriceReveal() public {
        // Shouldn't see price when 1 LINK = 20 USDC
        vm.expectRevert();
        amm.getPriceGated();

        // Should see price when 1 LINK = 31 USDC after this swap
        vm.startPrank(SWAPPER1_ADDR);
        vm.warp(block.timestamp + 11);
        baseAsset.approve(saddress(address(amm)), suint256(50000 * WAD));
        amm.swap(suint256(50000 * WAD), suint256(0));
        vm.stopPrank();
        amm.getPriceGated();
    }

    /*
     * Test case for swap timing. If the user attempts to swap too quickly,
     * the swap should revert.
     */
    function test_SwapTiming() public {
        vm.startPrank(SWAPPER1_ADDR);

        baseAsset.approve(saddress(address(amm)), suint256(50000 * WAD));

        // Immediately attempt another swap
        // Should revert due to timing restriction
        vm.expectRevert("Must wait 10 seconds before calling swap");
        amm.swap(suint256(50000 * WAD), suint256(0));

        // Wait 10 seconds and try again
        vm.warp(block.timestamp + 11);
        amm.swap(suint256(50000 * WAD), suint256(0));
        vm.stopPrank();
    }

    /*
     * Test case for access control. If the user is not a listener, they should
     * not be able to call swap or getPriceGated.
     */
    function test_Access() public {
        // Non-listener should not be able to call swap
        vm.startPrank(NON_LISTENER_ADDR);
        vm.expectRevert("You are not the listener");
        amm.swap(suint256(50000 * WAD), suint256(0));
        vm.stopPrank();

        // Unauthorized call to getPriceGated should revert
        vm.startPrank(NON_LISTENER_ADDR);
        vm.expectRevert();
        amm.getPriceGated();
        vm.stopPrank();

        // After the address gains listener status, they can call swap
        vm.startPrank(NON_LISTENER_ADDR);
        baseAsset.approve(saddress(address(amm)), suint256(50000 * WAD));
        amm.listen();
        vm.warp(block.timestamp + 11);
        amm.swap(suint256(50000 * WAD), suint256(0));
        amm.getPriceGated();
        vm.stopPrank();
    }

    /*
     * Test case for zero swap. If the user attempts to swap zero of both assets,
     * then there is no change in the price.
     */
    function test_ZeroSwap() public {
        vm.startPrank(SWAPPER1_ADDR);
        amm.listen();
        vm.warp(block.timestamp + 11);
        uint256 priceT0 = amm.getPrice();
        baseAsset.approve(saddress(address(amm)), suint256(50000 * WAD));
        amm.listen();
        vm.warp(block.timestamp + 11);
        amm.swap(suint256(0), suint256(0));
        vm.stopPrank();

        vm.startPrank(SWAPPER2_ADDR);
        amm.listen();
        vm.warp(block.timestamp + 11);
        quoteAsset.approve(saddress(address(amm)), suint256(50000 * WAD));
        amm.swap(suint256(0), suint256(0));

        amm.listen();
        vm.warp(block.timestamp + 11);
        assertEq(priceT0, amm.getPrice());
        vm.stopPrank();
    }

    /*
     * Test case for liquidity invariance. If two different listeners perform
     * swaps, the price should remain almost the same with some level of rounding
     * error.
     */
    function test_LiquidityInvariance() public {
        uint256 baseBefore = amm.getBaseReserve();
        uint256 quoteBefore = amm.getQuoteReserve();

        uint256 invariantBefore = baseBefore * quoteBefore;

        // Have two different listeners perform swaps
        vm.startPrank(SWAPPER1_ADDR);
        vm.warp(block.timestamp + 11);
        baseAsset.approve(saddress(address(amm)), suint256(50000 * WAD));
        amm.swap(suint256(500 * WAD), suint256(0));
        vm.stopPrank();

        uint256 baseAfterSwp1 = amm.getBaseReserve();
        uint256 quoteAfterSwp1 = amm.getQuoteReserve();

        uint256 invariantAfterSwp1 = baseAfterSwp1 * quoteAfterSwp1;

        vm.startPrank(SWAPPER2_ADDR);
        vm.warp(block.timestamp + 11);
        baseAsset.approve(saddress(address(amm)), suint256(20000 * WAD));
        amm.swap(suint256(200 * WAD), suint256(0));
        vm.stopPrank();

        uint256 baseAfterSwp2 = amm.getBaseReserve();
        uint256 quoteAfterSwp2 = amm.getQuoteReserve();
        uint256 invariantAfterSwp2 = baseAfterSwp2 * quoteAfterSwp2;
        // Allow a small tolerance for rounding error.
        assertApproxEqRel(invariantBefore, invariantAfterSwp1, 1e16);
        assertApproxEqRel(invariantBefore, invariantAfterSwp2, 1e16);
    }

    /*
     * Test case for listenedOnce. If the user attempts to call getPrice too quickly,
     * it should revert.
     */
    function test_ListenedOnce() public {
        vm.startPrank(SWAPPER1_ADDR);
        amm.listen();
        vm.warp(block.timestamp + 11);
        amm.getPrice();
        vm.expectRevert();
        amm.getPrice();
        vm.stopPrank();
    }
}
