#lang racket/base

;; Script to apply a patch to a Racket install
;; - Saves the files to-be-overwritten
;; - Clobbers a few files with a patch
;; - Rebuilds Racket

(require
  "common.rkt"
  (only-in racket/system system))

;; =============================================================================

;; Get the source for the Racket directory,
;; save original contract files,
;; apply patch,
;; recompile the contract directory.
(module+ main
  (require racket/cmdline)
  ;; --
  (define *rkt* (make-parameter #f))
  (define *verbose* (make-parameter #t))
  ;; --
  (command-line
   #:program "tracers-setup"
   #:once-each
   [("-q" "--quiet")  "Run quietly" (*verbose* #f)]
   [("-r" "--racket") r-param "Directory containing Racket source to modify." (*rkt* r-param)]
   #:args ()
   (begin
     (define v? (*verbose*))
     (debug v? "Searching for racket installation...")
     (define rkt-dir
       (or (parse-rkt-dir (*rkt*))
           (and v? (read-rkt-dir))
           (infer-rkt-dir)))
     (unless rkt-dir
       (raise-user-error 'setup "Error: could not find a Racket install. Goodbye."))
     (debug v? (format "Found Racket directory '~a', copying backup files..." rkt-dir))
     (save-backups rkt-dir)
     (debug v? (format "Saved backup files to '~a' directory. Applying patch..." backup-dir))
     (define p+r*
       (for/list ([p+r (in-list patch+recompile*)])
         (define path
           (string-append (path->string (current-directory)) "/" (car p+r)))
         (unless (file-exists? path)
           (raise-user-error 'setup (format "Error: could not find patch file '~a'. Goodbye." path)))
         (cons path (cdr p+r))))
     (for/and ([p+r (in-list p+r*)])
       (define patch (car p+r))
       (define r (cdr p+r))
       (parameterize ([current-directory rkt-dir])
         (system (string-append "git apply -v " patch)))
       (debug v? (format "Patch succeeded! Recompiling '~a'.\n" r))
       (recompile rkt-dir r)))))
