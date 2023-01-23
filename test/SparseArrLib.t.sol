// SPDX-License-Identifier: Beerware
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { SparseArrLib } from "../src/SparseArrLib.sol";

contract SparseArrLibTest is Test {
    bytes32 internal constant BEEF = bytes32(uint256(0xbeef));
    bytes32 internal constant BABE = bytes32(uint256(0xbabe));

    /// @notice Test array.
    uint256[] public arr;

    function setUp() public { }

    /// @notice Tests that appending to an array at the next expected slot works as expected.
    function test_store_append_succeeds() public {
        bytes32 slot = _getArrSlot();
        SparseArrLib.store(slot, 0, BEEF);
        assertEq(SparseArrLib.get(slot, 0), BEEF);
    }

    /// @notice Tests that overwriting a value at an existing, non-zero slot works as expected.
    function test_store_overwrite_succeeds() public {
        bytes32 slot = _getArrSlot();
        SparseArrLib.store(slot, 0, BEEF);
        SparseArrLib.store(slot, 0, BABE);
        assertEq(SparseArrLib.get(slot, 0), BABE);
    }

    /// @notice Helper function to get the storage slot of `arr`
    function _getArrSlot() internal pure returns (bytes32 _slot) {
        assembly {
            _slot := arr.slot
        }
    }
}
