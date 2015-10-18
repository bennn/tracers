#lang typed/racket/base

(require/typed "from.rkt"
  [nums (Listof Integer)]
  [funs (Listof (-> Boolean Boolean Boolean))]
  [idks (List Symbol String Integer (List))]
  [lam (-> (Listof Natural) (Listof Natural))])

(define (main)
  (apply + nums)
  ((car funs) #t #f)
  ;((cadr funs) (car funs) (car funs))
  (string-append
    (symbol->string (car idks))
    (cadr idks)
    (number->string (caddr idks))
    (if (eq? '() (cadddr idks)) "yolo" "no"))
  (lam '(8 6 7 5 3 0 9))
  (void))

(main)

