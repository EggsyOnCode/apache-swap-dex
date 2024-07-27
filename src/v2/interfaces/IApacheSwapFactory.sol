// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IApacheSwapFactory {
    // Errors
    error PairExists();
    error IdenticalTokens();
    error ZeroAddress();

    // Events
    event PairCreated(address indexed token0, address indexed token1, address pair);

    // Public variables
    function s_pairs(address token0, address token1) external view returns (address);
    function s_allPairs(uint256 index) external view returns (address);

    // Functions
    function createNewTokenPair(address _token0, address _token1) external returns (address pair);
    function sortTokens(address _token0, address _token1) external pure returns (address token0, address token1);
}
