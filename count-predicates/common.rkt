#lang racket/base

(provide
  backup-dir
  ;; Path-String
  ;; Directory to save overwritten files to.

  overridden-files
  ;; (Listof String)
  ;; List of filenames that the patch will modify

  patch+recompile*
  ;; (Listof (Pairof String String))
  ;; Names of the patchfiles to apply

  debug
  ;; #'(-> Boolean String Void)
  ;; Macro, prints the second argument if the first is #t

  recompile
  ;; (->* [Path-String] [String] Boolean)
  ;; Recompile the Racket installation rooted at the first argument.
  ;; If a second argument is given, use it as the compilation target.
  ;; Return a flag indicating whether the build was successful.

  infer-rkt-dir
  ;; (-> (U #f Path-String))
  ;; Infer the location of the user's Racket installation by searching
  ;; for the `racket` executable

  parse-rkt-dir
  ;; (-> (U #f Path-String) (U #f Path-String))
  ;; Check that the argument is the root of a Racket install.
  ;; Return #f on failure.

  read-rkt-dir
  ;; (-> (U #f Path-String))
  ;; Query the user for their favorite Racket install.
  ;; Return #f if they lied and gave an argument that was not a Racket install.

  save-backups
  ;; (-> Path-String Void)
  ;; Save the files to-be-overwritten that live inside the directory.

  restore-backups
  ;; (-> Path-String Void)
  ;; Move already-saved backup files back to the directory.
)

(require
  (only-in racket/list last)
  (only-in racket/string string-split)
  (only-in racket/system system))

;; =============================================================================
;; Constants

(define backup-dir "./_backup")
(define contract.rkt "racket/collects/racket/contract.rkt")
(define core.rkt "racket/share/pkgs/typed-racket-lib/typed-racket/core.rkt")

(define overridden-files
  '("racket/collects/racket/contract/private/guts.rkt"
    "racket/share/pkgs/typed-racket-lib/typed-racket/utils/require-contract.rkt"))

(define patch+recompile*
  `(("./patch/guts.patch" . ,contract.rkt)
    ("./patch/require-contract.patch" . ,core.rkt)))

;; -----------------------------------------------------------------------------

;; Print a message if the flag `v?` is set
(define-syntax-rule (debug v? msg)
  (when v?
    (displayln (string-append "[INFO] " msg))))

;; Recompile a racket install. Skip building the docs to save time.
(define (recompile rkt-dir [only-this-file #f])
  (parameterize ([current-directory rkt-dir])
    (if only-this-file
        (system (format "raco make -v ~a" only-this-file))
        (system "env PLT_SETUP_OPTIONS='-D' make"))))

;; -----------------------------------------------------------------------------

;; Try to guess the correct racket installation
(define (infer-rkt-dir)
  (define p (find-executable-path "racket"))
  (define s (and p (path->string p)))
  (define m (and s (regexp-match (regexp "^(.*)/racket/bin/racket$") s)))
  (and m (cadr m)))

;; Ensure that the path-string "looks like" a Racket install
(define (parse-rkt-dir dir)
  (if (or (not dir) (not (directory-exists? dir)))
    (begin
      (when dir (printf "Warning: directory '~a' does not exist\n" dir))
      #f)
    (and (for/and ([o-file (in-list overridden-files)])
           (or (file-exists? (string-append dir "/" o-file))
               (and (printf "Warning: file '~a' does not exist under directory '~a'\n" o-file dir)
                    #f)))
         dir)))

;; Prompt user to enter a path-string to their Racket install.
(define (read-rkt-dir)
  (printf "Enter the full path to your Racket install:\n")
  (define rkt (read-line))
  (when (eof-object? rkt)
    (raise-user-error 'config "Got EOF, shutting down."))
  (parse-rkt-dir rkt))

;; -----------------------------------------------------------------------------

;; Copy backup files to some place.
;; (: copy-backups (-> Path-String (U 'save 'restore) Void))
(define (copy-backups rkt-dir mode)
  (for ([o-file (in-list overridden-files)])
    (define orig (string-append rkt-dir "/" o-file))
    (define bk (string-append backup-dir "/" (last (string-split o-file "/"))))
    (case mode
     [(save) (copy-file orig bk #t)]
     [(restore) (copy-file bk orig #t)]
     [else (error 'copy-backups (format "Unknown mode '~a'" mode))])))

(define (save-backups rkt-dir)
  (unless (directory-exists? backup-dir)
    (make-directory backup-dir))
  (copy-backups rkt-dir 'save))

(define (restore-backups rkt-dir)
  (copy-backups rkt-dir 'restore))
