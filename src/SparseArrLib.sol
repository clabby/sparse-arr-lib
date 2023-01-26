// SPDX-License-Identifier: Beerware
pragma solidity ^0.8.17;

/// @title SparseArrLib
/// @author clabby <https://github.com/clabby>
/// @author N0xMare <https://github.com/N0xMare>
/// @notice A library for handling sparse storage arrays.
/// ─────────────────────────────────────────────────────
/// TODO:
/// - [ ] Finalize core logic.
///   - [ ] Optimize
/// - [x] Add tests for core `store` / `get` / `deleteAt` logic.
///   - [ ] Fix known bugs with edges / deleting the same sparse (i.e. non-canonical) index twice.
///     - [x] Fix certain cases where the binary search can recurse infinitely.
///   - [ ] Invariant tests
///     - [x] After `n` `store` operations and `m` `deleteAt` operations, the array length should be `n - m`.
///     - [ ] ...
///   - [ ] Gas profiling over a wide range of array sizes / deletions.
/// - [x] Add utility functions such as `pop`, `push`, etc.
library SparseArrLib {
    ////////////////////////////////////////////////////////////////
    //                   Sparse Array Wranglin'                   //
    ////////////////////////////////////////////////////////////////

    error DeletionUnderflow();

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
            // Grab the sparse length of the array from storage.
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
            // the sparse length.
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
    /// @dev WARNING! This function will not revert when deleting an element with a
    ///      canonical index less than the largest deleted canonical index. If this
    ///      is done, the data structure will break! Only use this function if you
    ///      ensure that this will never happen elsewhere in your code.
    /// @param slot The storage slot of the array to delete the element from.
    /// @param index The index of the element to delete.
    function deleteAt(bytes32 slot, uint256 index) internal {
        // Compute the storage slot of the deleted elements subarray.
        bytes32 sparseSlot = computeSparseSlot(slot);

        // TODO: Handle deletions at the same relative index twice.
        // TODO: Do not require linear progression of deletions (? - this would kinda suck to do)
        // TODO: Ensure edge deletions are handled correctly.
        assembly {
            let length := sload(slot)

            // If the requested index is greater than or equal to the array length, revert.
            // Out of bounds deletions are not allowed
            if iszero(lt(index, length)) {
                // Store the `Panic(uint256)` selector in scratch space
                mstore(0x00, 0x4e487b71)
                // Store the out of bounds panic code in scratch space.
                mstore(0x20, 0x20)
                // Revert with `Panic(32)`
                revert(0x1c, 0x24)
            }

            // Decrement the sparse length of the target array by 1.
            sstore(slot, sub(length, 0x01))

            // Fetch the total offset from the deleted elements subarray
            // (the total offset is just the length)
            let totalOffset := sload(sparseSlot)

            // Increment the total offset of the deleted elements subarray by 1.
            let newTotalOffset := add(totalOffset, 0x01)
            sstore(sparseSlot, newTotalOffset)

            // Store the sparse slot in scratch space for hashing.
            mstore(0x00, sparseSlot)

            // Store the canonical index of the deleted element as well as the sparse
            // offset of elements proceeding it.
            // Canonical index = index + sparseOffset
            sstore(add(totalOffset, keccak256(0x00, 0x20)), add(index, newTotalOffset))
        }
    }

    /// @notice Removes an element from the array at the given index and adds a new
    ///         sparse offset to the deleted elements subarray.
    /// @dev This function *will* revert if the canonical index of `index` is less than
    ///      the largest deleted canonical index.
    /// @param slot The storage slot of the array to delete the element from.
    /// @param index The index of the element to delete.
    function safeDeleteAt(bytes32 slot, uint256 index) internal {
        // Compute the storage slot of the deleted elements subarray.
        bytes32 sparseSlot = computeSparseSlot(slot);

        // TODO: Handle deletions at the same relative index twice.
        // TODO: Do not require linear progression of deletions (? - this would kinda suck to do)
        // TODO: Ensure edge deletions are handled correctly.
        assembly {
            let length := sload(slot)

            // If the requested index is greater than or equal to the array length, revert.
            // Out of bounds deletions are not allowed
            if iszero(lt(index, length)) {
                // Store the `Panic(uint256)` selector in scratch space
                mstore(0x00, 0x4e487b71)
                // Store the out of bounds panic code in scratch space.
                mstore(0x20, 0x20)
                // Revert with `Panic(32)`
                revert(0x1c, 0x24)
            }

            // Store the sparse slot in scratch space for hashing.
            mstore(0x00, sparseSlot)

            // Get the slot of the first element in the deleted elements subarray
            let sparseStartSlot := keccak256(0x00, 0x20)

            // Fetch the total offset from the deleted elements subarray
            // (the total offset is just the length)
            let totalOffset := sload(sparseSlot)

            // Do not allow deletion of a canonical index that is less than the largest deleted canonical index.
            if lt(add(index, totalOffset), sload(add(sparseStartSlot, sub(totalOffset, 0x01)))) {
                // Store the `DeletionUnderflow()` selector in scratch space
                mstore(0x00, 0xdb199ace)
                // Revert with `DeletionUnderflow()`
                revert(0x1c, 0x04)
            }

            // Decrement the sparse length of the target array by 1.
            sstore(slot, sub(length, 0x01))

            // Increment the total offset of the deleted elements subarray by 1.
            let newTotalOffset := add(totalOffset, 0x01)
            sstore(sparseSlot, newTotalOffset)

            // Store the canonical index of the deleted element as well as the sparse
            // offset of elements proceeding it.
            // Canonical index = index + sparseOffset
            sstore(add(totalOffset, sparseStartSlot), add(index, newTotalOffset))
        }
    }

    /// @notice Push a value onto the end of the array.
    /// @param slot The storage slot of the array to push to.
    /// @param contents The value to push onto the array.
    function push(bytes32 slot, bytes32 contents) internal {
        uint256 length;
        assembly {
            length := sload(slot)
        }

        // Compute the slot for the given index in the array stored at `slot`
        bytes32 rawTargetSlot = computeIndexSlot(slot, length);
        // Get the sparse offset at the given index
        uint256 offset = getSparseOffset(slot, length);

        assembly {
            // We are appending to the array- increment the length by 1.
            sstore(slot, add(length, 0x01))

            // Store the contents at the computed slot.
            sstore(add(rawTargetSlot, offset), contents)
        }
    }

    /// @notice Pop, removes the last item of the sparse array if array length is greater than 0
    /// @param slot The storage slot of the array to delete the element from.
    function pop(bytes32 slot) internal {
        assembly {
            let length := sload(slot)
            if iszero(length) {
                // Store the `Panic(uint256)` selector in scratch space
                mstore(0x00, 0x4e487b71)
                // Store the out of bounds panic code in scratch space.
                mstore(0x20, 0x20)
                // Revert with `Panic(32)`
                revert(0x1c, 0x24)
            }
            sstore(slot, sub(length, 0x01))
        }
    }

    ////////////////////////////////////////////////////////////////
    //                          Helpers                           //
    ////////////////////////////////////////////////////////////////

    /// @notice Performs a binary search on all the deleted elements in the array to find
    /// the sparse offset of the given index.
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

                // Only perform a search for the offset if the index >= (firstDeletionIndex - 1)
                // Otherwise, the offset is always zero.
                if iszero(lt(index, sub(sload(sparseSlot), 0x01))) {
                    // Subtract one from the high bound to set it to the final *index* rather than
                    // the length of the deleted elements subarray.
                    high := sub(high, 0x01)

                    // TODO: Optimize inner loop
                    for {
                        // Calculate the midpoint of [low, high] with a floor div
                        let mid := shr(0x01, add(low, high))
                        // Get the canonical index of the midpoint in the deleted elements subarray.
                        let midIndex := sload(add(sparseSlot, mid))
                        // Get the sparse offset of the midpoint in the deleted elements subarray.
                        _offset := add(mid, 0x01)
                    } iszero(gt(low, high)) {
                        // Calculate the midpoint of [low, high] with a floor div
                        mid := shr(0x01, add(low, high))
                        // Get the canonical index of the midpoint in the deleted elements subarray.
                        midIndex := sload(add(sparseSlot, mid))
                        // Get the sparse offset of the midpoint in the deleted elements subarray.
                        _offset := add(mid, 0x01)
                    } {
                        // Calculate the canonical index
                        let canonicalIndex := add(index, _offset)

                        // If the canonical index is less than the index at the midpoint, set the high bound to mid - 1
                        if lt(canonicalIndex, midIndex) {
                            high := sub(mid, 0x01)
                            continue
                        }
                        // If the canonical index is greater than the index at the midpoint, set the low bound to mid + 1
                        if gt(canonicalIndex, midIndex) {
                            low := add(mid, 0x01)
                            continue
                        }
                        // If the indexes are equal, we've found our offset!
                        break
                    }
                }
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
    /// @return _slot The storage slot for the sparse offset of the array.
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
