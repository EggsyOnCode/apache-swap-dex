// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract ApacheSwapPair is ERC20, ReentrancyGuard, Ownable {
    // errors
    error IncorrectAddress();
    error AlreadyInit();
    error TransferFailed();
    error InsufficientLiq();
    error InsufficientLiquidityBurned();
    error InvalidOutAmount();
    error InvalidK();

    // events
    event LP_Minted(address indexed to, uint256 liq);
    event LP_Burnt(address indexed to, uint256 amount0, uint256 amount1, uint256 liq);
    event Swapped(uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out, address to);

    address public s_token0;
    address public s_token1;
    uint256 private s_reserve0;
    uint256 private s_reserve1;

    // constants
    /// @dev Minimum LP tokens to be minted; prevents price fluctuations somehow?
    uint256 public constant MIN_LIQ = 1000;

    constructor() ERC20("ApacheSwapV1 Pair", "APR-LP") Ownable(msg.sender) {}

    function initialize(address _token0, address _token1) public onlyOwner {
        if (_token0 == address(0) || _token1 == address(0)) {
            revert IncorrectAddress();
        }

        if (s_token0 != address(0) || s_token1 != address(0)) {
            revert AlreadyInit();
        }

        s_token0 = _token0;
        s_token1 = _token1;
        s_reserve0 = s_reserve1 = 0;
    }

    function mint(address to) public returns (uint256 liq) {
        // Check the amt of each token deposited by the user
        uint256 amt0 = IERC20(s_token0).balanceOf(address(this)) - s_reserve0;
        uint256 amt1 = IERC20(s_token1).balanceOf(address(this)) - s_reserve1;

        // based on the deposited amt, calculate LP tokens proportionally
        // if the tokens are being minted for the first time then use Geometric Mean
        // otherwise choose the token which has the min reserves ratio
        if (totalSupply() == 0) {
            liq = Math.sqrt(amt0 * amt1) - MIN_LIQ;
            _mint(address(0), MIN_LIQ);
        } else {
            liq = Math.min((amt0 * totalSupply()) / s_reserve0, (amt1 * totalSupply()) / s_reserve1);
        }

        if (liq <= 0) {
            revert InsufficientLiq();
        }

        // transfer them
        _mint(to, liq);

        emit LP_Minted(to, liq);
    }

    function burn(address to) public returns (uint256 amount0, uint256 amount1) {
        // calculate amt of LP tokens sent by the user to the contract to be burnt
        uint256 liq = balanceOf(address(this));

        //calculating the recent balance of the contract to prevent price manipulations due to direct token transfers into contract
        uint256 balance0 = IERC20(s_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(s_token1).balanceOf(address(this));

        // proportion of each token wrt LP tokens that the user will receive in return for LP tokens
        amount0 = (liq * balance0) / totalSupply();
        amount1 = (liq * balance1) / totalSupply();

        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidityBurned();

        // burn the LP tokens and transfer tokens to user
        _burn(address(this), liq);
        _safeTransfer(s_token0, to, amount0);
        _safeTransfer(s_token1, to, amount1);

        //update the reserves

        emit LP_Burnt(to, amount0, amount1, liq);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to) public nonReentrant {
        if (amount0Out <= 0 && amount1Out <= 0) {
            revert InvalidOutAmount();
        }

        if (amount0Out > s_reserve0 || amount1Out > s_reserve1) {
            revert InsufficientLiq();
        }

        // we are optimistic that user has transferred the funds; ensured in the Router
        if (amount0Out > 0) _safeTransfer(s_token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(s_token1, to, amount1Out);

        // calculate the deposited tokens by the user (amount0In, amount1In)
        /// @dev : if reserves0 (vanry) = 1000; res (usdc) = 1000; i wanna get 100 vanry ; i deposit 100 usdc
        /// now: post-swap: 900 vanry (balance) and 1100 usdc ; amount0In (900 !> (1000-100)) hence is 0; amount1In would be 100
        uint256 balance0 = IERC20(s_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(s_token0).balanceOf(address(this));

        uint256 amount0In = balance0 > s_reserve0 - amount0Out ? balance0 - (s_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > s_reserve1 - amount1Out ? balance1 - (s_reserve1 - amount1Out) : 0;

        // Adjusted = balance before swap - swap fee; fee stays in the contract
        uint256 balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
        uint256 balance1Adjusted = (balance1 * 1000) - (amount1In * 3);

        // Constant product market maker formula ensured ; product of reserves after swap must be greater or equal to product of reserves
        // before
        if (balance0Adjusted * balance1Adjusted < uint256(s_reserve0) * uint256(s_reserve1) * (1000 ** 2)) {
            revert InvalidK();
        }

        emit Swapped(amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, value));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    // getters

    function getReserves() public view returns (uint256, uint256) {
        return (s_reserve0, s_reserve1);
    }
}
