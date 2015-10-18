snake
===

Snake game, adapted from the work on [soft contracts](https://github.com/philnguyen/soft-contract).

Sample Output
---
From `trace-run.rkt`

```
[DEBUG:1]Checking preconditions for 'main.rkt'...
[DEBUG:1]Compiling 'main.rkt' ...
[DEBUG:1]Compilation succeeded, running 'main.rkt' ...
[DEBUG:1]Aggregating results

Results
=======
Created 29 contracts
Checked contracts 17575714 times
The worst boundary (data.rkt -> data-adaptor.rkt) created 9 contracts and caused 15826005 checks
Worst values, for each boundary:
- [data.rkt => data-adaptor.rkt] value 'posn?' checked 5693802 times
- [cut-tail.rkt => motion-help.rkt] value 'cut-tail' checked 407700 times
- [world> => data-adaptor.rkt] value '(#<syntax:/home/ben/code/racket/tracers/count-predicates/examples/snake/data-adaptor.rkt:8:12' checked 275101 times
- [snake> => data-adaptor.rkt] value '(#<syntax:/home/ben/code/racket/tracers/count-predicates/examples/snake/data-adaptor.rkt:6:12' checked 275101 times
- [posn> => data-adaptor.rkt] value '(#<syntax:/home/ben/code/racket/tracers/count-predicates/examples/snake/data-adaptor.rkt:4:12' checked 241502 times
- [motion.rkt => main.rkt] value 'world->world' checked 241300 times
- [motion-help.rkt => motion.rkt] value 'snake-slither' checked 241100 times
- [handlers.rkt => main.rkt] value 'handle-key' checked 33800 times
- [motion.rkt => handlers.rkt] value 'world-change-dir' checked 33800 times
- [const.rkt => motion.rkt] value 'BOARD-HEIGHT' checked 1 times
- [const.rkt => collide.rkt] value 'BOARD-HEIGHT' checked 1 times
- [const.rkt => main.rkt] value 'WORLD' checked 1 times
- [data.rkt => motion.rkt] value 'posn=?' checked 0 times
- [data.rkt => collide.rkt] value 'posn=?' checked 0 times
- [collide.rkt => handlers.rkt] value 'snake-self-collide?' checked 0 times
```

From `list-boundaries.rkt`.
```
Results for 's.rktd'
====================
  29 contracts generated
  17575714 total checks
* Boundary from 'data.rkt' to 'data-adaptor.rkt' created 9 contracts (31%) and caused 15826005 checks (90%)
```
