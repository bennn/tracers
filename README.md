tracers
=======

Library for tracing the runtime flow of values in a program.


Goal
----
Imagine a program _p_ run on input values _i*_.
The modulues in _p_ work together to compute some result; doing so, they pass values between one another.
Some of these "roads" between modules might be very heavily used.

Our goal is to identify high-traffic paths between modules.
We hope these paths will explain performance characteristics and suggest optimizations (like tracing JIT).

