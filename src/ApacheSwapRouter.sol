// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ApacheSwapPair} from "./ApacheSwapPair.sol";
import {IApacheSwapPair} from "./interfaces/IApacheSwapPair.sol";
import {IApacheSwapFactory} from "./interfaces/IApacheSwapFactory.sol";
import {ApacheSwapLib} from "./ApacheSwapLib.sol";

contract ApacheSwapRouter {
    // errors
    error SafeTransferFailed();
    error InsufficientOutputAmt();
    error ExcessiveInputAmount();

    // events
    event LiquidityAdded(
        address tokenA, address tokenB, uint256 amountA, uint256 amountB, uint256 liquidity, address to
    );

    // modifiers

    modifier requireCorrectTokenInputs(address tokenA, address tokenB) {
        if (tokenA == tokenB) {
            revert IApacheSwapFactory.IdenticalTokens();
        }

        if (tokenA == address(0) || tokenB == address(0)) {
            revert IApacheSwapFactory.ZeroAddress();
        }
        _;
    }

    // storage
    IApacheSwapFactory public factory;

    constructor(address _factory) {
        factory = IApacheSwapFactory(_factory);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to // address to whom LP tokens will be minted
    ) public requireCorrectTokenInputs(tokenA, tokenB) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
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

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to // address to whom tokens will be returned
    ) public requireCorrectTokenInputs(tokenA, tokenB) {
        address pairAddress = ApacheSwapLib.pairFor(address(factory), tokenA, tokenB);

        // transferring LP tokens to Pair contract
        _safeTransferFrom(pairAddress, msg.sender, pairAddress, liquidity);

        // burning
        (uint256 burntA, uint256 burntB) = IApacheSwapPair(pairAddress).burn(to);
        if (burntA < amountAMin || burntB < amountBMin) {
            revert ApacheSwapLib.InsufficientAmount();
        }
    }

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to)
        external
        returns (uint256[] memory amounts)
    {
        amounts = ApacheSwapLib.getAmountsOut(address(factory), amountIn, path);
        if (amounts[amounts.length - 1] < amountOutMin) {
            revert InsufficientOutputAmt();
        }
        _safeTransferFrom(path[0], msg.sender, ApacheSwapLib.pairFor(address(factory), path[0], path[1]), amountIn);

        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to)
        public
        returns (uint256[] memory amounts)
    {
        amounts = ApacheSwapLib.getAmountsIn(address(factory), amountOut, path);
        if (amounts[amounts.length - 1] > amountInMax) {
            revert ExcessiveInputAmount();
        }
        _safeTransferFrom(path[0], msg.sender, ApacheSwapLib.pairFor(address(factory), path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = ApacheSwapLib.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? ApacheSwapLib.pairFor(address(factory), output, path[i + 2]) : _to;
            ApacheSwapPair(ApacheSwapLib.pairFor(address(factory), input, output)).swap(amount0Out, amount1Out, to);
        }
    }
}
