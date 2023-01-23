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

    /// TODO
    function test_store_appendAfterDeletion_succeeds() public { }

    /// TODO
    function test_store_overwriteAfterDeletion_succeeds() public { }

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
        SparseArrLib.store(slot, 4, BABE);
        assertEq(SparseArrLib.get(slot, 4), BABE);

        // Delete element at index 1
        SparseArrLib.deleteAt(slot, 1);

        // Assert that index 0 retained its original value.
        assertEq(SparseArrLib.get(slot, 0), BEEF);
        // Assert that index 1 now contains the value that used to be at index 2
        assertEq(SparseArrLib.get(slot, 1), BABE);
        // Assert that index 2 now contains the value that used to be at index 3
        assertEq(SparseArrLib.get(slot, 2), BEEF);
        // Assert that index 3 now contains the value that used to be at index 4
        assertEq(SparseArrLib.get(slot, 3), BABE);
    }

    /// @notice Tests that after deleting two values from a sparse array, the indexes of the
    /// values are shifted appropriately.
    function test_deleteAt_doubleDelete_works() public {
        bytes32 slot = _getArrSlot();

        // Insert 5 elements into the sparse array
        SparseArrLib.store(slot, 0, BEEF);
        assertEq(SparseArrLib.get(slot, 0), BEEF);
        SparseArrLib.store(slot, 1, BEEF);
        assertEq(SparseArrLib.get(slot, 1), BEEF);
        SparseArrLib.store(slot, 2, BABE);
        assertEq(SparseArrLib.get(slot, 2), BABE);
        SparseArrLib.store(slot, 3, BEEF);
        assertEq(SparseArrLib.get(slot, 3), BEEF);
        SparseArrLib.store(slot, 4, BABE);
        assertEq(SparseArrLib.get(slot, 4), BABE);

        // Assert that the length was properly updated
        assertEq(arr.length, 5);

        // Delete elements at canonical index 1 & 3 (adj: 1 & 2)
        SparseArrLib.deleteAt(slot, 1); // new:  [BEEF, BABE, BEEF, BABE]
        SparseArrLib.deleteAt(slot, 2); // new:  [BEEF, BABE, BABE]

        // Assert that index 0 retained its original value.
        assertEq(SparseArrLib.get(slot, 0), BEEF);
        // Assert that index 1 now contains the value that used to be at index 2
        assertEq(SparseArrLib.get(slot, 1), BABE);
        // Assert that index 2 now contains the value that used to be at index 4
        assertEq(SparseArrLib.get(slot, 2), BABE);

        // Assert that the length was properly updated
        assertEq(arr.length, 3);
    }

    /// @notice Tests that after deleting multiple values from a sparse array, the indexes of the
    /// values are shifted appropriately.
    function test_deleteAt_manyDeletions_works() public {
        bytes32 slot = _getArrSlot();

        // Insert 10 elements into the sparse array
        for (uint256 i; i < 10; ++i) {
            bytes32 ins = i % 2 == 0 ? BEEF : BABE;
            SparseArrLib.store(slot, i, ins);
            assertEq(SparseArrLib.get(slot, i), ins);
        }

        // Assert that the length was properly updated
        assertEq(arr.length, 10);

        // Delete elements at index 1, 3, & 5
        SparseArrLib.deleteAt(slot, 1); // new: [BEEF, BEEF, BABE, BEEF, BABE, BEEF, BABE, BEEF, BABE]
        SparseArrLib.deleteAt(slot, 3); // new: [BEEF, BEEF, BABE, BABE, BEEF, BABE, BEEF, BABE]
        SparseArrLib.deleteAt(slot, 5); // new: [BEEF, BEEF, BABE, BABE, BEEF, BEEF, BABE]

        // TODO: Fix
        assertEq(SparseArrLib.get(slot, 0), BEEF);
        assertEq(SparseArrLib.get(slot, 1), BEEF);
        assertEq(SparseArrLib.get(slot, 2), BABE);
        assertEq(SparseArrLib.get(slot, 3), BABE);
        assertEq(SparseArrLib.get(slot, 4), BEEF);
        assertEq(SparseArrLib.get(slot, 5), BEEF);
        assertEq(SparseArrLib.get(slot, 6), BABE);
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
