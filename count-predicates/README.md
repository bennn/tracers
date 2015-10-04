count-predicates
================

Strategy
--------
- Attach a contract to every value in the program with `require/typed`.
- Count flow-of-values by counting _predicate contract_ applications.

Each contract generated by `require/typed` will include a payload:
- The identifier under contract
- The file that required the id (and generated the contract)

These payloads will be checked whenever we do a predicate contract check because predicates are easy to monitor.
They all happen in the same place, instead of being spread throughout the contract library.


Details
-------
- Use a patch to override `contract/private/guts.rkt` and `typed-racket/utils/require-contract.rkt`.


Install
-------


Extras
------
