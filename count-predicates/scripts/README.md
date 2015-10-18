scripts
=======

Scripts to collect info on traced contracts & present the results.

Example usage:
```
> racket trace-run.rkt -o output.rktd ../examples/factorial/main.rkt
[DEBUG:1]Checking preconditions for '../examples/factorial/main.rkt'...
[DEBUG:1]Compiling '../examples/factorial/main.rkt' ...
[DEBUG:1]Compilation succeeded, running '../examples/factorial/main.rkt' ...
[DEBUG:1]Aggregating results

Results
=======
Created 3 contracts
Checked contracts 5 times
The worst boundary (fact.rkt -> main.rkt) created 3 contracts and caused 5 checks
Worst values, for each boundary:
- [fact.rkt => main.rkt] value 'fact-acc' checked 2 times

> racket list-boundaries output.rktd
Results for 'output.rktd'
=========================
  3 contracts generated
  5 total checks
* Boundary from 'fact.rkt' to 'main.rkt' created 3 contracts (100%) and caused 5 checks (100%)
```

- `list-boundaries.rkt`
  Summarize the boundaries in a program; processes data produced by `trace-run.rkt`.
- `trace-run.rkt`
  Run a project while tracking contract information.
  Uses the log messages produced by a modified Racket installation.
