#lang racket/base

;; Run a Racket file while tracking contract-count output.
;; - Print summary results to console
;; - (Optionally) given a `-o FILE.rktd` filename, save detailed result to file

(provide
  (struct-out boundary)
)

;; -----------------------------------------------------------------------------

(require
  (only-in racket/list first second third fourth fifth last)
  (only-in racket/match match-define)
  (only-in racket/system system process)
  (only-in racket/string string-join string-split string-replace string-prefix?)
  (only-in racket/file copy-directory/files)
)

;; =============================================================================
;; -- constants

;; Higher value = Print more debug information
(define DEBUG 1)

;; -----------------------------------------------------------------------------
;; -- util

(define-syntax-rule (arg-error msg arg* ...)
  (raise-user-error 'trace-run:commandline (format msg arg* ...)))

(define-syntax-rule (debug N msg arg* ...)
  (when (<= N DEBUG)
    (printf "[DEBUG:~a]" N)
    (printf msg arg* ...)
    (newline)))

(define-syntax-rule (precondition-error msg arg* ...)
  (raise-user-error 'trace-run:precondition (format msg arg* ...)))

(define-syntax-rule (warning msg arg* ...)
  (displayln (string-append "WARNING: " (format msg arg* ...))))

;; Not implemented.
;; THE IDEA: check that the user's racket installation matches the files in the `patch-racket` directory
;; (: ensure-hacked-racket (-> Void))
(define (ensure-hacked-racket)
  (void))

;; Get the last part (the filename + extension) from a path.
;; (: path-last (-> Path String))
(define (path-last p)
  (path->string (last (explode-path p))))

;; -----------------------------------------------------------------------------
;; -- parsing results (logs -> contract information)

;; Data representing a line of output about contracts.
;; Log messages are always tab-separated (in Ben's instrumented Racket)
;;   TAG    ID    TO-FILE    VALUE    FROM-FILE
(struct contract-log (
  tag       ;; (U 'create 'apply)
  uid       ;; Natural : A unique identifier for each created contract
  to-file   ;; String  : Name of file that imported the value and created the contract
  value     ;; String  : Name of the value wrapped in a contract
  from-file ;; String  : Name of the file that provided the value
) #:transparent)
;; (define-type ContractLog contract-log)

;; Convert a line of log information to a struct
;; (: string->contract-log (-> String ContractLog))
(define (string->contract-log tag line)
  (define tag+id+to+val+from (string-split line))
  (contract-log
   tag
   (second tag+id+to+val+from)
   (third  tag+id+to+val+from)
   (fourth tag+id+to+val+from)
   (fifth  tag+id+to+val+from)))

;; If `line` is a message logging a new contract, return a `contract-log` struct
;; (: trace-create? (-> String (U ContractLog #f)))
(define (trace-create? line)
  (cond
   [(string-prefix? line "[TRACE:CREATE]")
    (string->contract-log 'create line)]
   [else #f]))

;; If `line` is a message logging a boundary contract application,
;; return a `contract-log` struct
;; (: trace-apply? (-> String (U ContractLog #f)))
(define (trace-apply? line)
  (cond
   [(string-prefix? line "[TRACE:APPLY]")
    (string->contract-log 'create line)]
   [else #f]))

;; Add a new contract, represented by `clog`, to the map `cmap`.
;; (: add-contract (-> ContractUsageMap (-> ContractLog Void)))
(define ((add-contract cmap) clog)
  (match-define (contract-log tag uid to-file val from-file) clog)
  ;; Get the hashtable for contracts out of `from-file`, else create it.
  (define from-hash (hash-ref cmap from-file (lambda () #f)))
  (cond
   [(not from-hash)
    (hash-set! cmap from-file (make-hash (list (cons to-file (make-hash (list (cons val 0)))))))]
   [else
    ;; Get the hashtable for contracts in to `to-file`, else create a new one
    (define to-hash (hash-ref from-hash to-file (lambda () #f)))
    (cond
     [(not to-hash)
      (hash-set! from-hash to-file (make-hash (list (cons val 0))))]
     [else
      ;; Get the hashtable for contracts on the value `val`
      ;; (This should always fail)
      (define val-count (hash-ref to-hash val (lambda () #f)))
      (cond
       [(not val-count)
        (hash-set! to-hash val 0)]
       [else
        (warning "Duplicate contract on value '~a', from '~a' to '~a'. (new id '~a')" val from-file to-file uid)])])]))

;; Increment the usage count for the contract `clog` in the map `cmap`.
;; (: add-contract (-> ContractUsageMap (-> ContractLog ContractUsageMap)))
(define ((update-contract cmap) clog)
  (define (missing-key key)
    (error 'trace-run:update-contract "Missing key '~a', cannot update information for contract '~a'" key clog))
  (match-define (contract-log tag uid to-file val from-file) clog)
  (define from-hash (hash-ref cmap from-file (lambda () #f)))
  (cond
   [(not from-hash)
    (missing-key from-file)]
   [else
    ;; Get the hashtable for contracts in to `to-file`, else create a new one
    (define to-hash (hash-ref from-hash to-file (lambda () #f)))
    (cond
     [(not to-hash)
      (missing-key to-file)]
     [else
      (define val-count (hash-ref to-hash val (lambda () #f)))
      (cond
       [(not val-count)
        (missing-key val)]
       [else
        (hash-set! to-hash val (add1 val-count))])])]))

;; -----------------------------------------------------------------------------
;; -- show (display parsed logging information -- show me what the contracts did)

(struct boundary (
  from-file ;; String  : where contracts came from
  to-file   ;; String  : where contracts went to
  val       ;; String  : the identifier covered with a contract
  checks    ;; Natural : the number of times the identifier was used
) #:prefab)
;; (define-type Boundary boundary)

;; True if `b1` is "more expensive" than `b2`. i.e. is called more
;; (: boundary<? (-> Boundary Boundary Boolean))
(define (boundary>? b1 b2)
  (> (boundary-checks b1) (boundary-checks b2)))

;; Return a list of all contracts, represented as `boundary` structs
;; The list is partially sorted; for each from/to pair, the most expensive boundaries come first.
;; (: all-boundaries (-> ContractUsageMap (Listof Boundary)))
(define (all-boundaries from->to #:valid-filenames [valid? #f])
  (for*/list ([(from to->id) (in-hash from->to)]
              [(to id->nat) (in-hash to->id)]
              #:when (or (not valid?)
                         (and (valid? from) (valid? to))))
    (sort
     (for/list ([(val count) (in-hash id->nat)]) (boundary from to val count))
     boundary>?)))

;; Informal documentation for output .rktd files.
;; Belongs at the top of these printed files.
(define DATA-FORMAT
  (string-join '(";; Data is a list of lists of boundary structures"
                 ";; There is one inner list for each boundary in the program"
                 ";; The boundary structures have 4 fields"
                 ";; - from-file : String"
                 ";; - to-file  : String"
                 ";; - val : String"
                 ";; - checks : Natural")
               "\n"))

;; Fold over a `ContractUsageMap`.
;; (: fold-cmap (All (A) (->* [(-> A Natural A) A ContractUsageMap] [#:from (U #f String) #:to (U #f String)] A)))
(define (fold-cmap f init from->to #:from [only-from #f] #:to [only-to #f])
  (for*/fold ([acc init])
             ([to->id (or (and only-from (cond [(hash-ref from->to only-from (lambda () #f))
                                               => (lambda (x) (list x))]
                                              [else '()]))
                         (in-hash-values from->to))]
             [id->nat (or (and only-to (cond [(hash-ref to->id only-to (lambda () #f))
                                              => (lambda (x) (list x))]
                                             [else '()]))
                          (in-hash-values to->id))]
             [num-checks (in-hash-values id->nat)])
    (f acc num-checks)))

;; Count the total number of contracts represented in the map
;; (: count-contracts (->* [ContractUsageMap] [#:from (U #f String) #:to (U #f String)] Natural))
(define (count-contracts from->to #:from [only-from #f] #:to [only-to #f])
  (fold-cmap (lambda (acc checks) (add1 acc))
             0
             from->to
             #:from only-from
             #:to only-to))

;; Count the total number of contract checks / applications in the map
;; (: count-checks (->* [ContractUsageMap] [#:from (U #f String) #:to (U #f String)] Natural))
(define (count-checks from->to #:from [only-from #f] #:to [only-to #f])
  (fold-cmap (lambda (acc checks) (+ acc checks))
             0
             from->to
             #:from only-from
             #:to only-to))

;; Return a list of the worst contracts, one for each pair of files.
;; Sort results in order of "most checks" to "fewest checks"
;; (: filter-worst-boundaries (-> ContractUsageMap (Listof Boundary)))
(define (filter-worst-boundaries from->to #:valid-filename? [valid? #f])
  (define unsorted-worst
    ;; For each from/to pair, pick the most expensive value
    (for*/list ([(from to->id) (in-hash from->to)]
                [(to id->nat)  (in-hash to->id)]
                #:when (or (not valid?) ;; No filter = accept everything
                           (and (valid? from) (valid? to))))
      ;; Make a boundary struct with each
      (define-values (best-val best-count)
        (for/fold ([bval #f] [bcnt #f])
                  ([(val count) (in-hash id->nat)])
          (if (or (not (and bval bcnt))
                  (< bcnt count))
              (values val count)
              (values bval bcnt))))
      (boundary from to best-val best-count)))
  (sort unsorted-worst boundary>?))

;; Convert a boundary struct to a pretty string
;; (: format-boundary (-> Boundary String))
(define (format-boundary bnd)
  (match-define (boundary from to val checks) bnd)
  (format "[~a => ~a] value '~a' checked ~a times" from to val checks))

;; -----------------------------------------------------------------------------
;; -- main

;; Database of contracts created & used during program execution
;;
;; (define-type Filename Symbol)
;; (define-type Identifier Symbol)
;; (define-type ContractUsageMap
;;   (HashTable Filename ;; FROM
;;              (HashTable Filename ;; TO
;;                         (HashTable Identifier ;; VALUE
;;                                    Natural))))

;; Run the filename, collect run-time contract information (num created & used)
;; return a map of results
;; (: collect-contract (-> Path-String ContractUsageMap))
(define (collect-contract fname)
  (debug 1 "Checking preconditions for '~a'..." fname)
  (define contract-log (make-hash '()))
  (define add-contract/log    (add-contract    contract-log))
  (define update-contract/log (update-contract contract-log))
  ;; Compile
  (debug 1 "Compiling '~a' ..." fname)
  (unless (system (string-append "raco make " fname))
    (error 'trace-run:compile (format "Compilation failed for '~a', shutting down." fname)))
  ;; Run
  (debug 1 "Compilation succeeded, running '~a' ..." fname)
  (match-define (list stdout stdin pid stderr ping) (process (string-append "racket " fname)))
  ;; Collect the results in a map
  (for ([line (in-lines stdout)])
    (cond
     [(trace-create? line) => add-contract/log]
     [(trace-apply?  line) => update-contract/log]
     [else (debug 2 "Ignoring line '~a'" line)]))
  (close-input-port stdout)
  (close-output-port stdin)
  (close-input-port stderr)
  contract-log)

;; Display aggregate stats about the contracts
;; (: show-contract (-> ContractUsageMap Void))
(define (show-contract cmap #:output-file [out-opt #f] #:valid-filename? [valid? #f])
  (debug 1 "Aggregating results")
  (define num-contracts (count-contracts cmap))
  (define num-checks (count-checks cmap))
  (define worst-boundaries (filter-worst-boundaries cmap #:valid-filename? valid?))
  (printf "\nResults\n=======\n")
  (printf "Created ~a contracts\n" num-contracts)
  (printf "Checked contracts ~a times\n" num-checks)
  (when (not (null? worst-boundaries))
    (match-define (boundary wfrom wto wval wchecks) (car worst-boundaries))
    (define worst-total-contracts (count-contracts cmap #:from wfrom #:to wto))
    (define worst-total-checks (count-checks cmap #:from wfrom #:to wto))
    (printf "The worst boundary (~a -> ~a) created ~a contracts and caused ~a checks\n" wfrom wto worst-total-contracts worst-total-checks)
    (printf "Worst values, for each boundary:\n- ~a\n" (string-join (map format-boundary worst-boundaries) "\n- ")))
  ;; Print the all things to file
  (when out-opt
    (with-output-to-file out-opt #:exists 'replace
      (lambda () (displayln DATA-FORMAT) (write (all-boundaries cmap))))))

;; =============================================================================
;; Usage: `racket trace-run.rkt PROJECT-DIR`

(module+ main
  (require racket/cmdline)
  ;; -- parameters
  (define valid-file* (make-parameter '()))
  (define output-path (make-parameter #f))
  (define (set-param/contract val #:param p #:contract c)
    (unless (c val)
      (arg-error "Expected a '~a', got '~a'" c val))
    (p val))
  ;; -- command line
  (command-line
   #:program "trace-run"
   #:multi
   [("-f" "--fname") f-p
                     "Show results only for this file"
                     (valid-file* (cons f-p (valid-file*)))]
   #:once-each
   [("-o" "--output") o-p
                      "A path to write output to"
                      (set-param/contract o-p #:param output-path #:contract path-string?)]
   #:args (fname)
    (begin
      (ensure-hacked-racket)
      ;; -- run the project, collect contract information
      (define contract-set (collect-contract fname))
      (define valid-file?
        (let ([v* (valid-file*)])
          (if (null? (valid-file*))
              #f
              (lambda (f) (member f v*)))))
      ;; -- print a summary of the collected information
      (show-contract contract-set
                     #:output-file (output-path)
                     #:valid-filename? valid-file?))))
