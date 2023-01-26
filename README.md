# `sparse-arr-lib` [![License](https://img.shields.io/badge/License-Beerware-green)](./LICENSE.md)

> **Warning**
> This library is unfinished & is a WIP. Use discretion, don't test in prod.


A library to assist with utilizing sparse storage arrays in Solidity.

## Rationale

In Solidity, it is impossible to delete an element from the middle of a storage array without shifting all elements
following the deleted element, disrupting order, or leaving a gap. This library is an experiment to enable the use of a
**sparse array**-esq data structure to combat this shortcoming as efficiently as possible.

### Intended Behavior
![Sparse Demo](./assets/sparse_arr.png)

### How does it work?
Before any elements are deleted, the library will treat the array as if it is normal- Elements will both be retrieved and
stored at their canonical indicies (the **canonical index** is the true index of the element within the array, sans any offsets.)

When the first element is deleted with `deleteAt`, a sub array of deleted elements is created at slot `keccak256(abi.encode(arrSlot, 0x535041525345))`.
This array contains the canonical indicies of the deleted elements.

If the subarray of deleted elements contains any values when a call to `store`, `push`, or `get` is made, a binary search will be performed over the array
in order to find the nearest offset that is less than or equal to the supplied relative index.

### Current limitations:
- Elements must be deleted linearly and in continuously ascending order. (i.e., one cannot delete index `5` and then `3`). This is due to the fact that the deleted elements subarray must be sorted for the binary search to work properly.
  - BUG: An element may not be deleted at the same relative index more than once. 

## Usage

To view docs, run `forge doc --serve` and navigate to `http://localhost:3000/`.
