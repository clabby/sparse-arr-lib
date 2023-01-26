pragma solidity ^0.8.17;

import { InvariantTest } from "forge-std/InvariantTest.sol";
import { Test } from "forge-std/Test.sol";
import { SparseArrLib } from "../../src/SparseArrLib.sol";
import { StdUtils } from "forge-std/StdUtils.sol";

/// @notice An actor that can
contract SparseArrActor is StdUtils {
    /// @notice The test sparse array
    uint256[] public arr;

    /// @notice The number of items stored in the invariant test run
    uint256 public numStores;

    /// @notice The number of items deleted in the invariant test run
    uint256 public numDeletes;

    /// @dev Store a value in the sparse array at `index`
    function store(uint256 index, bytes32 contents) public {
        // Bound `index` to [0, len(arr)]
        index = bound(index, 0, arr.length);

        // Only increment `numStores` if the store operation is appending to the array.
        // Otherwise, the store operation is overwriting an existing value.
        if (index == arr.length) {
            numStores++;
        }

        // Store the contents at `index`
        SparseArrLib.store(_getArrSlot(), index, contents);
    }

    /// @dev Push a value to the end of the sparse array
    function push(bytes32 contents) public {
        SparseArrLib.push(_getArrSlot(), contents);
        numStores++;
    }

    /// @dev Delete a value from the sparse array at `index`
    function deleteAt(uint256 index) public {
        index = bound(index, 0, arr.length - 1);

        SparseArrLib.deleteAt(_getArrSlot(), index);
        numDeletes++;
    }

    /// @dev Delete a value from the sparse array at `index`, but only if it can
    /// be safely deleted.
    function safeDeleteAt(uint256 index) public {
        index = bound(index, 0, arr.length - 1);

        SparseArrLib.safeDeleteAt(_getArrSlot(), index);
        numDeletes++;
    }

    /// @dev Pop a value off of the end of the sparse array.
    function pop() public {
        SparseArrLib.pop(_getArrSlot());
        numDeletes++;
    }

    /// @dev Helper to get `arr`'s length in the test contract
    function getArrLength() public view returns (uint256) {
        return arr.length;
    }

    /// @dev Helper to get the storage slot of `arr`
    function _getArrSlot() internal pure returns (bytes32 _slot) {
        assembly {
            _slot := arr.slot
        }
    }
}

contract SparseArrLib_InvariantTest is Test, InvariantTest {
    SparseArrActor public actor;

    function setUp() public {
        // Create a new actor
        actor = new SparseArrActor();

        // Target the actor
        targetContract(address(actor));
    }

    /// @notice Test that the sparse array's length is always equal to the number of items stored
    /// minus the number of items deleted.
    function invariant_length() public {
        assertEq(actor.getArrLength(), actor.numStores() - actor.numDeletes());
    }
}
