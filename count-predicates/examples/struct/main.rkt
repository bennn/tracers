#lang typed/racket/base

(require/typed "data.rkt"
  [#:struct anystruct (
    [var : String]
    [fun : (-> Natural Natural Natural (Pairof Natural Natural))]
    [vec : (Vectorof (U Symbol Integer))]
   )]
  [s1 anystruct])

(define s2 (anystruct "yes" (lambda (a b c) (cons 1 1)) (vector 8)))
(define v1 (anystruct-var s1))
(define v2 ((anystruct-fun s1) 1 1 1))
(define v3 (vector-ref (anystruct-vec s1) 2))
