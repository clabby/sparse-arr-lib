// SPDX-License-Identifier: Beerware
pragma solidity ^0.8.17;

/// @title SparseArrLib
/// @author clabby <https://github.com/clabby>
/// @notice A library for handling sparse storage arrays.
/// --------------------------------------------------------
/// TODO:
/// - [ ] Finalize core logic.
///   - [ ] Optimize
/// - [ ] Add tests for core `store` / `get` / `deleteAt` logic.
///   - [ ] Fix known bugs with edges.
///   - [ ] Gas profiling
/// - [ ] Add utility functions such as `pop`, `push`, etc.
library SparseArrLib {
    ////////////////////////////////////////////////////////////////
    //                   Sparse Array Wranglin'                   //
    ////////////////////////////////////////////////////////////////

    /// @notice Stores a value within a sparse array
    /// @param slot The storage slot of the array to write to.
    /// @param index The index within the sparse array to write `contents` to.
    /// @param contents The value to write to the array at `index`.
    function store(bytes32 slot, uint256 index, bytes32 contents) internal {
        // Compute the slot for the given index in the array stored at `slot`
        bytes32 rawTargetSlot = computeIndexSlot(slot, index);
        // Get the sparse offset at the given index
        uint256 offset = getSparseOffset(slot, index);

        assembly {
            // Grab the canonical length of the array from storage.
            let length := sload(slot)

            // Do not allow out of bounds writes.
            if gt(index, length) {
                // Store the `Panic(uint256)` selector in scratch space
                mstore(0x00, 0x4e487b71)
                // Store the out of bounds panic code in scratch space.
                mstore(0x20, 0x20)
                // Revert with `Panic(32)`
                revert(0x1c, 0x24)
            }

            // If the index is equal to the length, then we are appending to the array.
            // Otherwise, we are overwriting an existing value, so we don't need to update
            // the canonical length.
            if eq(index, length) { sstore(slot, add(length, 0x01)) }

            // Store the contents at the computed slot.
            sstore(add(rawTargetSlot, offset), contents)
        }
    }

    /// @notice Retrieves a value from a sparse array at a given index.
    /// TODO: Explain what's going on here.
    /// @param slot The storage slot of the array to read from.
    /// @param index The index within the array to read from.
    /// @return _value The value at the given index in the array.
    function get(bytes32 slot, uint256 index) internal view returns (bytes32 _value) {
        assembly {
            // If the requested index is greater than or equal to the length of the array, revert.
            if iszero(lt(index, sload(slot))) {
                // Store the `Panic(uint256)` selector in scratch space
                mstore(0x00, 0x4e487b71)
                // Store the out of bounds panic code in scratch space.
                mstore(0x20, 0x20)
                // Revert with `Panic(32)`
                revert(0x1c, 0x24)
            }
        }

        // Compute the slot for the given index in the array stored at `slot`
        bytes32 rawTargetSlot = computeIndexSlot(slot, index);
        // Get the sparse offset at the given index
        uint256 offset = getSparseOffset(slot, index);

        assembly {
            // Fetch the value at `index` within the sparse array.
            _value := sload(add(rawTargetSlot, offset))
        }
    }

    /// @notice Removes an element from the array at the given index and adds a new
    ///         sparse offset to the deleted elements subarray.
    /// @param slot The storage slot of the array to delete the element from.
    /// @param index The index of the element to delete.
    function deleteAt(bytes32 slot, uint256 index) internal {
        // Compute the storage slot of the deleted elements subarray.
        bytes32 sparseSlot = computeSparseSlot(slot);
        // Get the sparse offset for the given index.
        uint256 sparseOffset = getSparseOffset(slot, index);

        // TODO: Do not allow out of bounds deletions.
        // TODO: Handle deletions at the same index twice.
        // TODO: Handle edge deletions.
        assembly {
            // Decrement the canonical length of the target array by 1.
            sstore(slot, sub(sload(slot), 0x01))

            // Fetch the total offset from the deleted elements subarray
            // (the total offset is just the length)
            let totalOffset := sload(sparseSlot)

            // Increment the total offset of the deleted elements subarray by 1.
            let newTotalOffset := add(totalOffset, 0x01)
            sstore(sparseSlot, newTotalOffset)

            // Store the sparse slot in memory for hashing.
            mstore(0x00, sparseSlot)

            // Store the canonical index of the deleted element as well as the sparse
            // offset of elements proceeding it.
            // Canonical index = index + sparseOffset
            sstore(add(totalOffset, keccak256(0x00, 0x20)), or(shl(0x80, add(index, sparseOffset)), newTotalOffset))
        }
    }

    ////////////////////////////////////////////////////////////////
    //                          Helpers                           //
    ////////////////////////////////////////////////////////////////

    /// @notice Performs a binary search on all the deleted elements in the array to find
    /// the sparse offset of the given index.
    /// @dev BIT LAYOUT OF DELETED CONTENTS ARRAY ELEMENTS:
    /// - 128 high-order bits: The canonical index of the deleted element.
    /// - 128 low-order bits:  The sparse offset starting at the canonical index of the deleted element.
    /// @param slot The storage slot of the array to read from.
    /// @param index The index within the array to read from.
    /// @return _offset The sparse offset of the given index.
    function getSparseOffset(bytes32 slot, uint256 index) internal view returns (uint256 _offset) {
        // Compute the storage slot for the array of deleted elements.
        bytes32 sparseSlot = computeSparseSlot(slot);

        assembly {
            // Search for sparse offset of the given index by performing a binary
            // search on the deleted elements in the array.
            let low := 0x00
            let high := sload(sparseSlot)

            // If low and high are not equal, elements within the sparse array have been
            // deleted. We need to perform a binary search to find the sparse offset at
            // the given index.
            if xor(low, high) {
                // Store the sparse slot in scratch space for hashing
                mstore(0x00, sparseSlot)
                // Get the slot of the first element within the deleted elements array.
                sparseSlot := keccak256(0x00, 0x20)

                // Subtract one from the high bound to set it to the final *index* rather than
                // the length of the deleted elements subarray.
                high := sub(high, 0x01)

                // Calculate the midpoint of the deleted elements array.
                let mid := shr(0x01, add(low, high))
                // Get the value of the midpoint in the deleted elements subarray.
                let midVal := sload(add(sparseSlot, mid))
                // Shift in the canonical index of the deleted element at the midpoint
                let midIndex := shr(0x80, midVal)

                // TODO: Optimize inner loop
                // TODO: Fix bug where the search does not find the correct offset
                // among many deletions. We need a notion of canonical vs. sparse indexes here.
                for { } iszero(gt(low, high)) {
                    // Calculate the midpoint of [low, high] with a floor div
                    mid := shr(0x01, add(low, high))
                    // Get the value of the midpoint in the deleted elements subarray.
                    midVal := sload(add(sparseSlot, mid))
                    // Load the canonical index of the deleted element at the above midpoint
                    midIndex := shr(0x80, sload(midVal))
                } {
                    if lt(index, midIndex) {
                        high := sub(mid, 0x01)
                        continue
                    }

                    if gt(index, midIndex) {
                        low := add(mid, 0x01)
                        continue
                    }

                    break
                }

                // If the requested index is less than the canonical index of the fetched
                // deleted element, then the sparse offset is 0.
                // TODO: This can be cleaned up- we likely don't need to wait until after
                // the search to determine this. Can just check if the index is less than
                // the first deleted index.
                switch lt(index, midIndex)
                case 0x00 {
                    // Clear the canonical index from the first 128 bits of `midVal` to get the offset.
                    _offset := shr(0x80, shl(0x80, midVal))
                }
                case 0x01 { _offset := 0x00 }
            }
        }
    }

    /// @notice Computes the canonical storage slot for an `index` within an array at `slot`.
    /// @dev Will not revert if the index is out of bounds of the current array size.
    /// @param slot The storage slot of the array.
    /// @param index The desired index within the array.
    /// @return _slot The canonical storage slot for the given `index`.
    function computeIndexSlot(bytes32 slot, uint256 index) internal pure returns (bytes32 _slot) {
        assembly {
            // Store the array's length slot in scratch space
            mstore(0x00, slot)
            // Compute the slot for the index within the array
            _slot := add(keccak256(0x00, 0x20), index)
        }
    }

    /// @notice Computes the storage slot for the sparse offset of an array at `slot`.
    /// @param slot The storage slot of the array.
    function computeSparseSlot(bytes32 slot) internal pure returns (bytes32 _slot) {
        assembly {
            // Store the array's length slot in scratch space @ 0x00
            mstore(0x00, slot)
            // Store the sparse magic bytes in scratch space @ 0x20
            mstore(0x20, 0x535041525345)
            // Compute the slot for the sparse offset of the array
            _slot := keccak256(0x00, 0x40)
        }
    }
}
