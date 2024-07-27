// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IApacheSwapPair {
    // Errors
    error IncorrectAddress();
    error AlreadyInit();
    error TransferFailed();
    error InsufficientLiq();
    error InsufficientLiquidityBurned();
    error InvalidOutAmount();
    error InvalidK();

    // Events
    event LP_Minted(address indexed to, uint256 liq);
    event LP_Burnt(address indexed to, uint256 amount0, uint256 amount1, uint256 liq);
    event Swapped(uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out, address to);

    // Public variables
    function s_token0() external view returns (address);
    function s_token1() external view returns (address);
    function s_reserve0() external view returns (uint256);
    function s_reserve1() external view returns (uint256);
    function MIN_LIQ() external view returns (uint256);

    // Functions
    function initialize(address _token0, address _token1) external;
    function mint(address to) external returns (uint256 liq);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1);
}
