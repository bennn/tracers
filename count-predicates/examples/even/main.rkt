#lang typed/racket/base

(require/typed "even.rkt" [even? (-> (-> Natural Boolean) Natural Boolean)])

(: odd? (-> Natural Boolean))
(define (odd? n)
  (not (even? odd? n)))

(define (main)
  (let ([even? (lambda ([x : Natural]) (even? odd? x))])
    (even? 20)
    (odd? 20)
    (void)))

(main)
