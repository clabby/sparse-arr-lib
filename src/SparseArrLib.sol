// SPDX-License-Identifier: Beerware
pragma solidity ^0.8.17;

/// @title SparseArrLib
/// @author clabby <https://github.com/clabby>
/// @notice A library for handling sparse arrays in storage.
/// --------------------------------------------------------
/// @dev This library makes several assumptions:
/// 1. A zero value in the array is considered to be null. This library was written with
///    the assumption that the array is of type `bytes32[]`, where the `bytes32` value is
///    a hash.
/// --------------------------------------------------------
/// TODO:
/// - [ ] Finalize initial logic.
/// - [ ] Add tests for core `store` / `get` / `deleteIndex` logic.
/// - [ ] Add utility functions such as `pop`, `push`, etc.
library SparseArrLib {
    ////////////////////////////////////////////////////////////////
    //                   Sparse Array Wranglin'                   //
    ////////////////////////////////////////////////////////////////

    /// @notice Stores a value within a sparse array
    /// @param slot The storage slot of the array to write to.
    /// @param index The index within the array to write `contents` to.
    /// @param contents The value to write to the array at `index`.
    function store(bytes32 slot, uint256 index, bytes32 contents) internal {
        // Compute the value for the given index in the array starting at `slot`
        bytes32 destSlot = computeIndexSlot(slot, index);

        assembly {
            // Grab the canonical length of the array from storage.
            let length := sload(slot)

            switch gt(index, sub(length, 0x01))
            case 0x00 {
                // If the index is not greater than the current length - 1, we are updating
                // an existing slot and there is no need to update the length of the array.
                sstore(destSlot, contents)
            }
            case 0x01 {
                // If the index is greater than the current length - 1, we are appending an
                // element to the array. We need to update the length of the array accordingly.

                // Update the length of the array.
                sstore(slot, add(length, 0x01))

                // Check if the index is exactly `length`. If it is, we can just store the
                // contents in the slot. Otherwise, we need to create a pointer to the new
                // slot.
                switch eq(index, length)
                case 0x00 {
                    // TODO: Store a pointer to `index` in keccak(destSlot).
                }
                case 0x01 { sstore(destSlot, contents) }
            }
        }
    }

    /// @notice Removes an element from the array at the given index and creates a pointer
    ///         to the next element in the array.
    function deleteIndex(bytes32 slot, uint256 index) internal {
        bytes32 destSlot = computeIndexSlot(slot, index);

        assembly {
            let length := sload(slot)

            // Only allow deletions within the bounds of the array.
            switch lt(index, length)
            case 0x00 {
                // Store the `Panic(uint256)` selector in scratch space
                mstore(0x00, 0x4e487b71)
                // Store the out of bounds panic code in scratch space.
                mstore(0x20, 0x20)
                // Revert with `Panic(32)`
                revert(0x1c, 0x24)
            }
            case 0x01 {
                // Zero out the slot at `index`
                sstore(destSlot, 0x00)

                // Store `destSlot` in scratch space for hashing.
                mstore(0x00, destSlot)

                // Hash the slot for the pointer
                let pointerSlot := keccak256(0x00, 0x20)

                // Compute the slot of the next element in the array.
                destSlot := add(destSlot, 0x01)

                sstore(pointerSlot, destSlot)

                // Decrement the length of the array.
                sstore(slot, sub(length, 0x01))
            }
        }
    }

    /// @notice Retrieves a value from a sparse array at a given index.
    ///         If there is no value at the given index (signified by a zero value in the slot),
    ///         then we re-hash the slot at the given index to try to find a pointer to the
    ///         next slot in the list.
    ///
    ///         TODO: This method could be made more efficient, but not without sacrificing security.
    ///         If we bet on the unlikeliness of a hash containing more than 224 leading zero bits,
    ///         we could encode the next index in the slot of the original index itself in a uint32,
    ///         perform a bounds check, and re-hash the index without requiring a third `sload`.
    /// @param slot The storage slot of the array to read from.
    /// @param index The index within the array to read from.
    /// @return _value The value at the given index in the array.
    function get(bytes32 slot, uint256 index) internal view returns (bytes32 _value) {
        bytes32 targetSlot = computeIndexSlot(slot, index);
        assembly {
            // Fetch the value at the index `index` within the array.
            _value := sload(targetSlot)

            // If the value is zero, attempt to find a pointer to the next slot in the list.
            // Otherwise, we already have the value we're looking for.
            if iszero(_value) {
                // Store the initial slot in scratch space for hashing.
                mstore(0x00, targetSlot)

                // Hash the initial slot to attempt to get the next slot in the list.
                // Store it in `_value` for now (TODO: Is this more efficient than a new stack var?)
                _value := keccak256(0x00, 0x20)

                // Load the pointer to the next slot in the list.
                // Store it in `_value` for now (TODO: Is this more efficient than a new stack var?)
                _value := sload(_value)

                // If the pointer at the re-hashed slot is zero, we are out of bounds.
                if iszero(_value) {
                    // Store the `Panic(uint256)` selector in scratch space
                    mstore(0x00, 0x4e487b71)
                    // Store the out of bounds panic code in scratch space.
                    mstore(0x20, 0x20)
                    // Revert with `Panic(32)`
                    revert(0x1c, 0x24)
                }

                // Load the value at the next slot in the list.
                _value := sload(_value)
            }
        }
    }

    ////////////////////////////////////////////////////////////////
    //                          Helpers                           //
    ////////////////////////////////////////////////////////////////

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
