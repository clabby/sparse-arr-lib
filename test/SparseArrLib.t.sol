// SPDX-License-Identifier: Beerware
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { SparseArrLib } from "../src/SparseArrLib.sol";

contract SparseArrLibTest is Test {
    /// @notice 4byte error selector for `Panic(uint256)`
    bytes4 internal constant PANIC_SELECTOR = 0x4e487b71;

    /// @notice Test values
    bytes32 internal constant BEEF = bytes32(uint256(0xbeef));
    bytes32 internal constant BABE = bytes32(uint256(0xbabe));

    /// @notice Test array.
    uint256[] public arr;

    ////////////////////////////////////////////////////////////////
    //                       `store` tests                        //
    ////////////////////////////////////////////////////////////////

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
        assertEq(SparseArrLib.get(slot, 0), BEEF);
        SparseArrLib.store(slot, 0, BABE);
        assertEq(SparseArrLib.get(slot, 0), BABE);
    }

    /// @notice Tests that attempting to write to an out of bounds index causes `store` to revert
    /// with the expected data.
    function test_store_outOfBounds_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(PANIC_SELECTOR, 0x20));
        SparseArrLib.store(_getArrSlot(), 1, BEEF);
    }

    ////////////////////////////////////////////////////////////////
    //                        `get` tests                         //
    ////////////////////////////////////////////////////////////////

    /// @notice Tests that attempting to retrieve a value at an out of bounds index causes `get` to
    /// revert with the expected data.
    function test_get_outOfBounds_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(PANIC_SELECTOR, 0x20));
        SparseArrLib.get(_getArrSlot(), 0);
    }

    ////////////////////////////////////////////////////////////////
    //                      `deleteAt` tests                      //
    ////////////////////////////////////////////////////////////////

    /// @notice Tests that after deleting a single value from a sparse array, the indexes of the
    /// values are shifted appropriately.
    function test_deleteAt_singleDelete_works() public {
        bytes32 slot = _getArrSlot();
        SparseArrLib.store(slot, 0, BEEF);
        assertEq(SparseArrLib.get(slot, 0), BEEF);
        SparseArrLib.store(slot, 1, BEEF);
        assertEq(SparseArrLib.get(slot, 1), BEEF);
        SparseArrLib.store(slot, 2, BABE);
        assertEq(SparseArrLib.get(slot, 2), BABE);
        SparseArrLib.store(slot, 3, BEEF);
        assertEq(SparseArrLib.get(slot, 3), BEEF);

        // Delete element at index 1
        SparseArrLib.deleteAt(slot, 1);
        // Assert that index 0 retained its original value.
        assertEq(SparseArrLib.get(slot, 0), BEEF);
        // Assert that index 1 now contains the value that used to be at index 2
        assertEq(SparseArrLib.get(slot, 1), BABE);
        // Assert that index 2 now contains the value that used to be at index 3
        assertEq(SparseArrLib.get(slot, 2), BEEF);
    }

    /// @notice Tests that after deleting multiple values from a sparse array, the indexes of the
    /// values are shifted appropriately.
    function test_deleteAt_singleDelete_works() public {
        bytes32 slot = _getArrSlot();
        SparseArrLib.store(slot, 0, BEEF);
        assertEq(SparseArrLib.get(slot, 0), BEEF);
        SparseArrLib.store(slot, 1, BEEF);
        assertEq(SparseArrLib.get(slot, 1), BEEF);
        SparseArrLib.store(slot, 2, BABE);
        assertEq(SparseArrLib.get(slot, 2), BABE);
        SparseArrLib.store(slot, 3, BEEF);
        assertEq(SparseArrLib.get(slot, 3), BEEF);

        // Delete element at index 1
        SparseArrLib.deleteAt(slot, 1);
        // Assert that index 0 retained its original value.
        assertEq(SparseArrLib.get(slot, 0), BEEF);
        // Assert that index 1 now contains the value that used to be at index 2
        assertEq(SparseArrLib.get(slot, 1), BABE);
        // Assert that index 2 now contains the value that used to be at index 3
        assertEq(SparseArrLib.get(slot, 2), BEEF);
    }

    ////////////////////////////////////////////////////////////////
    //                          Helpers                           //
    ////////////////////////////////////////////////////////////////

    /// @notice Helper function to get the storage slot of `arr`
    function _getArrSlot() internal pure returns (bytes32 _slot) {
        assembly {
            _slot := arr.slot
        }
    }
}
