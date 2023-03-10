// SPDX-License-Identifier: Beerware
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { SparseArrLib } from "../src/SparseArrLib.sol";

contract SparseArrLib_UnitTest is Test {
    /// @notice 4byte error selector for `Panic(uint256)`
    bytes4 internal constant PANIC_SELECTOR = 0x4e487b71;

    /// @notice Test array.
    uint256[] public arr;

    error DeletionUnderflow();

    ////////////////////////////////////////////////////////////////
    //                       `store` tests                        //
    ////////////////////////////////////////////////////////////////

    /// @notice Tests that appending to an array at the next expected slot works as expected.
    function test_store_append_works() public {
        bytes32 slot = _getArrSlot();

        SparseArrLib.store(slot, 0, b(1));
        assertEq(SparseArrLib.get(slot, 0), b(1));
    }

    /// @notice Tests that overwriting a value at an existing, non-zero slot works as expected.
    function test_store_overwrite_works() public {
        bytes32 slot = _getArrSlot();

        SparseArrLib.store(slot, 0, b(1));
        assertEq(SparseArrLib.get(slot, 0), b(1));
        SparseArrLib.store(slot, 0, b(2));
        assertEq(SparseArrLib.get(slot, 0), b(2));
    }

    /// @notice Tests that appending a value to the array after a deletion works as expected.
    function test_store_appendAfterDeletion_works() public {
        bytes32 slot = _getArrSlot();

        // Store 3 elements in the sparse array.
        for (uint256 i; i < 3; ++i) {
            bytes32 ins = b(i + 1);
            SparseArrLib.store(slot, i, ins);
            assertEq(SparseArrLib.get(slot, i), ins);
        }

        // Assert that the length is correct.
        assertEq(arr.length, 3);

        // Delete index 1
        SparseArrLib.deleteAt(slot, 1);

        // Assert that the length is correct.
        assertEq(arr.length, 2);

        assertEq(SparseArrLib.get(slot, 0), b(1));
        assertEq(SparseArrLib.get(slot, 1), b(3));

        // Append a new element after deletion of index 1.
        SparseArrLib.store(slot, 2, b(4));

        // Assert that the length is correct.
        assertEq(arr.length, 3);

        assertEq(SparseArrLib.get(slot, 0), b(1));
        assertEq(SparseArrLib.get(slot, 1), b(3));
        assertEq(SparseArrLib.get(slot, 2), b(4));
    }

    /// @notice Tests that overwriting a value in the array after a deletion works as expected.
    function test_store_overwriteAfterDeletion_works() public {
        bytes32 slot = _getArrSlot();

        // Store 3 elements in the sparse array.
        for (uint256 i; i < 3; ++i) {
            bytes32 ins = b(i + 1);
            SparseArrLib.store(slot, i, ins);
            assertEq(SparseArrLib.get(slot, i), ins);
        }

        // Assert that the length is correct.
        assertEq(arr.length, 3);

        // Delete index 1
        SparseArrLib.deleteAt(slot, 1);

        assertEq(SparseArrLib.get(slot, 0), b(1));
        assertEq(SparseArrLib.get(slot, 1), b(3));

        // Assert that the length is correct.
        assertEq(arr.length, 2);

        // Append a new element after deletion of index 1.
        SparseArrLib.store(slot, 1, b(4));

        assertEq(SparseArrLib.get(slot, 0), b(1));
        assertEq(SparseArrLib.get(slot, 1), b(4));

        // Assert that the length did not change after overwriting index 1 post-deletion.
        assertEq(arr.length, 2);
    }

    /// @notice Tests that attempting to write to an out of bounds index causes `store` to revert
    /// with the expected data.
    function test_store_outOfBounds_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(PANIC_SELECTOR, 0x20));
        SparseArrLib.store(_getArrSlot(), 1, b(1));
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

        // Store 5 elements in the sparse array
        for (uint256 i; i < 5; ++i) {
            bytes32 ins = b(i + 1);
            SparseArrLib.store(slot, i, ins);
            assertEq(SparseArrLib.get(slot, i), ins);
        }

        // Assert that the length is correct.
        assertEq(arr.length, 5);

        // Delete element at index 1
        SparseArrLib.deleteAt(slot, 1);

        // Assert that the length is correct.
        assertEq(arr.length, 4);

        // Assert that index 0 retained its original value.
        assertEq(SparseArrLib.get(slot, 0), b(1));
        // Assert that index 1 now contains the value that used to be at index 2
        assertEq(SparseArrLib.get(slot, 1), b(3));
        // Assert that index 2 now contains the value that used to be at index 3
        assertEq(SparseArrLib.get(slot, 2), b(4));
        // Assert that index 3 now contains the value that used to be at index 4
        assertEq(SparseArrLib.get(slot, 3), b(5));
    }

    /// @notice Tests that after deleting two values from a sparse array, the indexes of the
    /// values are shifted appropriately.
    function test_deleteAt_doubleDelete_works() public {
        bytes32 slot = _getArrSlot();

        // Store 5 elements in the sparse array
        for (uint256 i; i < 5; ++i) {
            bytes32 ins = bytes32(uint256(i + 1));
            SparseArrLib.store(slot, i, ins);
            assertEq(SparseArrLib.get(slot, i), ins);
        }

        // Assert that the length is correct
        assertEq(arr.length, 5);

        // Delete elements at canonical index 1 & 3 (adj: 1 & 2)
        // .                                og: [1, 2, 3, 4, 5]
        SparseArrLib.deleteAt(slot, 1); // new: [1, 3, 4, 5]
        SparseArrLib.deleteAt(slot, 2); // new: [1, 3, 5]

        // Assert that index 0 retained its original value.
        assertEq(SparseArrLib.get(slot, 0), b(1));
        // Assert that index 1 now contains the value that used to be at index 2
        assertEq(SparseArrLib.get(slot, 1), b(3));
        // Assert that index 2 now contains the value that used to be at index 4
        assertEq(SparseArrLib.get(slot, 2), b(5));

        // Assert that the length is correct
        assertEq(arr.length, 3);
    }

    /// @notice Tests that after deleting multiple values from a sparse array, the indexes of the
    /// values are shifted appropriately.
    function test_deleteAt_manyDeletions_works() public {
        bytes32 slot = _getArrSlot();

        // Insert 10 elements into the sparse array
        for (uint256 i; i < 10; ++i) {
            bytes32 ins = bytes32(i);
            SparseArrLib.store(slot, i, ins);
            assertEq(SparseArrLib.get(slot, i), ins);
        }

        // Assert that the length is correct
        assertEq(arr.length, 10);

        // Delete elements at index 1, 3, 5, & 6
        // .                               og:  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        SparseArrLib.deleteAt(slot, 1); // new: [0, 2, 3, 4, 5, 6, 7, 8, 9]
        SparseArrLib.deleteAt(slot, 3); // new: [0, 2, 3, 5, 6, 7, 8, 9]
        SparseArrLib.deleteAt(slot, 5); // new: [0, 2, 3, 5, 6, 8, 9]
        SparseArrLib.deleteAt(slot, 6); // new: [0, 2, 3, 5, 6, 8]

        // Assert that the values at each index were properly shifted (if any shifting was necessary).
        assertEq(SparseArrLib.get(slot, 0), b(0));
        assertEq(SparseArrLib.get(slot, 1), b(2));
        assertEq(SparseArrLib.get(slot, 2), b(3));
        assertEq(SparseArrLib.get(slot, 3), b(5));
        assertEq(SparseArrLib.get(slot, 4), b(6));
        assertEq(SparseArrLib.get(slot, 5), b(8));

        // Assert that the length is correct
        assertEq(arr.length, 6);
    }

    /// @notice Tests that attempting to delete an out of bounds index causes `deleteAt` to revert
    function test_deleteAt_outOfBounds_reverts() public {
        bytes32 slot = _getArrSlot();

        // Store 5 elements in the sparse array
        for (uint256 i; i < 5; ++i) {
            bytes32 ins = bytes32(i);
            SparseArrLib.store(slot, i, ins);
            assertEq(SparseArrLib.get(slot, i), ins);
        }

        // Assert that the length is correct.
        assertEq(arr.length, 5);

        vm.expectRevert(abi.encodeWithSelector(PANIC_SELECTOR, 0x20));

        // Delete element at index 5 (Out of Bounds), revert
        SparseArrLib.deleteAt(slot, 5);
    }

    ////////////////////////////////////////////////////////////////
    //                    `safeDeleteAt` tests                    //
    ////////////////////////////////////////////////////////////////

    /// @notice Tests that `safeDeleteAt` reverts as expected when attempting to delete a canonical
    /// index that is less than the largest deleted canonical index.
    function test_safeDeleteAt_deletionUnderflow_reverts() public {
        bytes32 slot = _getArrSlot();

        // Store 5 elements in the sparse array
        for (uint256 i; i < 5; ++i) {
            bytes32 ins = bytes32(i);
            SparseArrLib.store(slot, i, ins);
            assertEq(SparseArrLib.get(slot, i), ins);
        }

        // Assert that the length is correct.
        assertEq(arr.length, 5);

        // Delete element at index 3
        SparseArrLib.safeDeleteAt(slot, 3);

        // Assert that the length is correct.
        assertEq(arr.length, 4);

        // Attempt to delete an element at a prior index.
        vm.expectRevert(DeletionUnderflow.selector);
        SparseArrLib.safeDeleteAt(slot, 2);
    }

    ////////////////////////////////////////////////////////////////
    //                        `push` tests                        //
    ////////////////////////////////////////////////////////////////

    /// @notice Tests that the `push` function works as expected before any deletions.
    function test_push_works() public {
        bytes32 slot = _getArrSlot();

        // Assert that the length is correct.
        assertEq(arr.length, 0);

        // Push 5 elements into the sparse array
        for (uint256 i; i < 5; ++i) {
            bytes32 ins = b(i + 1);
            SparseArrLib.push(slot, ins);
            assertEq(SparseArrLib.get(slot, i), ins);
        }

        // Assert that the length is correct.
        assertEq(arr.length, 5);
    }

    /// @notice Tests that the `push` function works as expected after deletions.
    function test_push_afterDelete_works() public {
        bytes32 slot = _getArrSlot();

        // Assert that the length is correct.
        assertEq(arr.length, 0);

        // Push 5 elements into the sparse array
        for (uint256 i; i < 5; ++i) {
            bytes32 ins = b(i + 1);
            SparseArrLib.push(slot, ins);
            assertEq(SparseArrLib.get(slot, i), ins);
        }

        // Delete an element at index 1.
        SparseArrLib.deleteAt(slot, 1);

        // Assert that the length is correct.
        assertEq(arr.length, 4);

        // Push a new element into the sparse array.
        SparseArrLib.push(slot, b(6));

        // Assert that the length is correct.
        assertEq(arr.length, 5);

        assertEq(SparseArrLib.get(slot, 0), b(1));
        assertEq(SparseArrLib.get(slot, 1), b(3));
        assertEq(SparseArrLib.get(slot, 2), b(4));
        assertEq(SparseArrLib.get(slot, 3), b(5));
        assertEq(SparseArrLib.get(slot, 4), b(6));
    }

    ////////////////////////////////////////////////////////////////
    //                        `pop` tests                         //
    ////////////////////////////////////////////////////////////////

    /// @notice Tests that the `pop` function works as expected.
    function test_pop_works() public {
        bytes32 slot = _getArrSlot();

        // Store 5 elements in the sparse array
        for (uint256 i; i < 5; ++i) {
            bytes32 ins = b(i + 1);
            SparseArrLib.store(slot, i, ins);
            assertEq(SparseArrLib.get(slot, i), ins);
        }

        // Assert that the length is correct.
        assertEq(arr.length, 5);

        // Pop the final element from the sparse array
        SparseArrLib.pop(slot);

        // Assert that the length is correct.
        assertEq(arr.length, 4);

        // Assert that the values at each index are correct
        for (uint256 i; i < 4; ++i) {
            assertEq(SparseArrLib.get(slot, i), b(i + 1));
        }

        // Assert that get() on the index that was previously popped now reverts
        vm.expectRevert(abi.encodeWithSelector(PANIC_SELECTOR, 0x20));
        SparseArrLib.get(slot, 4);
    }

    ////////////////////////////////////////////////////////////////
    //                       Gas Profiling                        //
    ////////////////////////////////////////////////////////////////

    // TODO

    ////////////////////////////////////////////////////////////////
    //                          Helpers                           //
    ////////////////////////////////////////////////////////////////

    /// @notice Helper function to get the storage slot of `arr`
    function _getArrSlot() internal pure returns (bytes32 _slot) {
        assembly {
            _slot := arr.slot
        }
    }

    /// @notice Helper to quickly cast a `uint256` to a `bytes32`
    function b(uint256 _val) internal pure returns (bytes32 _ret) {
        _ret = bytes32(_val);
    }
}
