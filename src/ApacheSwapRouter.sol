// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ApacheSwapPair} from "./ApacheSwapPair.sol";
import {IApacheSwapPair} from "./interfaces/IApacheSwapPair.sol";
import {IApacheSwapFactory} from "./interfaces/IApacheSwapFactory.sol";
import {ApacheSwapLib} from "./ApacheSwapLib.sol";

contract ApacheSwapRouter {
    // errors
    error SafeTransferFailed();

    // events
    event LiquidityAdded(
        address tokenA, address tokenB, uint256 amountA, uint256 amountB, uint256 liquidity, address to
    );

    // storage
    IApacheSwapFactory public factory;

    constructor(address _factory) {
        factory = IApacheSwapFactory(_factory);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to // address to whom LP tokens will be minted
    ) public returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        if (tokenA == tokenB) {
            revert IApacheSwapFactory.IdenticalTokens();
        }

        if (tokenA == address(0) || tokenB == address(0)) {
            revert IApacheSwapFactory.ZeroAddress();
        }

        // getting the pair address; if it doesn't exist already, it will have to be created
        if (factory.s_pairs(tokenA, tokenB) == address(0)) {
            factory.createNewTokenPair(tokenA, tokenB);
        }

        (amountA, amountB) = _calculateLiq(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pairAddress = ApacheSwapLib.pairFor(address(factory), tokenA, tokenB);

        // transferring tokens
        _safeTransferFrom(tokenA, msg.sender, pairAddress, amountA);
        _safeTransferFrom(tokenB, msg.sender, pairAddress, amountB);

        // minting LP tokens
        liquidity = IApacheSwapPair(pairAddress).mint(to);

        emit LiquidityAdded(tokenA, tokenB, amountA, amountB, liquidity, to);
    }

    function removeLiquidity() external {}
    function swapExactTokensForTokens() external {}

    function _calculateLiq(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256, uint256) {
        (uint256 reserveA, uint256 reserveB) = ApacheSwapLib.getReserves(address(factory), tokenA, tokenB);

        if (reserveA == 0 && reserveB == 0) {
            return (amountADesired, amountBDesired);
        } else {
            uint256 optimalB = ApacheSwapLib.quote(amountADesired, reserveA, reserveB);
            if (amountBDesired >= optimalB) {
                if (optimalB < amountBMin) {
                    revert ApacheSwapLib.InsufficientAmount();
                }
                return (amountADesired, optimalB);
            } else {
                uint256 optimalA = ApacheSwapLib.quote(amountBDesired, reserveB, reserveA);
                if (optimalA < amountAMin) {
                    revert ApacheSwapLib.InsufficientAmount();
                }
                return (optimalA, amountBDesired);
            }
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, value));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }
}
