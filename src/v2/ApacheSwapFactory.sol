// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ApacheSwapPair} from "./ApacheSwapPair.sol";
import {IApacheSwapPair} from "./interfaces/IApacheSwapPair.sol";

contract ApacheSwapFactory {
    // errors
    error PairExists();
    error IdenticalTokens();
    error ZeroAddress();

    // events
    event PairCreated(address indexed token0, address indexed token1, address pair);

    // storage
    mapping(address => mapping(address => address)) public s_pairs;
    address[] public s_allPairs;

    function createNewTokenPair(address _token0, address _token1) public returns (address pair) {
        if (_token0 == _token1) {
            revert IdenticalTokens();
        }

        (address token0, address token1) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);

        if (token0 == address(0) || token1 == address(0)) {
            revert ZeroAddress();
        }
        if (s_pairs[token0][token1] != address(0)) {
            revert PairExists();
        }

        bytes memory bytecode = type(ApacheSwapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        IApacheSwapPair(pair).initialize(token0, token1);

        s_pairs[token0][token1] = pair;
        s_pairs[token1][token0] = pair;
        s_allPairs.push(pair);

        emit PairCreated(token0, token1, pair);
    }

    function sortTokens(address _token0, address _token1) internal pure returns (address token0, address token1) {
        if (_token0 < _token1) {
            return (_token0, _token1);
        } else {
            return (_token1, _token0);
        }
    }
}
