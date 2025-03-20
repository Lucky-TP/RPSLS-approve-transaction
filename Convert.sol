// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract Convert {

    function convert(uint256 n) public pure returns (bytes32) {
        return bytes32(n);
    }

    function getHash(bytes32 data) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(data));
    }

    function getAddress() public view returns (address) {
        return address(this);
    }
}