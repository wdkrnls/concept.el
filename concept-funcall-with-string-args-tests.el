;;; concept-funcall-tests.el --- ERT checks for concept-funcall-with-string-args  -*- lexical-binding: t; -*-

;; Load the implementation, then this file, then:  M-x ert RET t RET
;; `ert' requires `cl-lib'; nothing in this file uses cl-lib itself.

(require 'ert)
(require 'concept nil t)   ; comment out if you load the implementation by hand

;;;; ---- fixtures -------------------------------------------------------

(defun concept-funcall-test--ordered (subject &optional relationship
                                              category from count)
  "Stand-in for `concept-expand-ordered-relationships'."
  (list subject relationship category from count))

(defun concept-funcall-test--rest (x &rest xs)
  "Fixture with a `&rest' parameter."
  (list x xs))

(defun concept-funcall-test--foo-bar (foo &optional bar)
  "Fixture of two scalars, so brackets can be probed."
  (list foo bar))

(defun concept-funcall-test--ambiguous (subject &optional relationship rank)
  "Fixture whose optionals share the prefix `r'."
  (list subject relationship rank))

(defun concept-funcall-test--two-required (subject relationship &optional x)
  "Fixture with two required parameters."
  (list subject relationship x))

(defun concept-funcall-test--named-arglist-p (arglist)
  "Non-nil when ARGLIST has at least one real parameter name."
  (let (found)
    (dolist (a (and (listp arglist) arglist))
      (when (and (symbolp a)
                 (not (memq a '(&optional &rest &key &aux)))
                 (not (string-match-p "\\`arg[0-9]+\\'" (symbol-name a))))
        (setq found t)))
    found))

(defun concept-funcall-test--report-arglist ()
  "Show what can be learned about the real target's argument list."
  (interactive)
  (let ((f #'concept-expand-ordered-relationships))
    (message "plain : %S\nnames : %S\nusable: %S"
             (ignore-errors (help-function-arglist f))
             (ignore-errors (help-function-arglist f t))
             (concept-funcall-test--named-arglist-p
              (ignore-errors (help-function-arglist f t))))))

;;;; ---- assertion helper -----------------------------------------------

(defmacro concept-funcall-test--signals (regexp &rest body)
  "Assert that BODY signals an error whose message matches REGEXP."
  (declare (indent 1))
  `(let* ((text-quoting-style 'grave)
          (err (should-error (progn ,@body))))
     (should (string-match-p ,regexp (error-message-string err)))))

;;;; ---- ordering -------------------------------------------------------

(ert-deftest concept-funcall-canonical-order ()
  (should (equal '("behaviors" nil "law" 1 3)
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--ordered
                  "subject: behaviors category: law from: 1 count: 3"))))

(ert-deftest concept-funcall-reordered-keywords ()
  (should (equal '("behaviors" nil "law" 1 10)
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--ordered
                  "from:1 count:10 subject: behaviors category: law"))))

(ert-deftest concept-funcall-explicit-relationship ()
  (should (equal '("behaviors" "include" nil 1 10)
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--ordered
                  "from:1 count:10 subject: behaviors relationship: include"))))

(ert-deftest concept-funcall-scalar-keyword-then-positional ()
  "A scalar keyword takes one value; a bare word after it is positional."
  (should (equal '("behaviors" nil "law" 1 3)
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--ordered
                  "category: law behaviors from: 1 count:3"))))

;;;; ---- gaps, truncation, arity ----------------------------------------

(ert-deftest concept-funcall-pads-interior-gap ()
  (should (equal '("behaviors" nil "law" nil nil)
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--ordered
                  "subject: behaviors category: law"))))

(ert-deftest concept-funcall-resolve-drops-trailing-optionals ()
  (should (equal '("behaviors")
                 (concept--funcall-resolve
                  '("behaviors") nil #'concept-funcall-test--ordered))))

(ert-deftest concept-funcall-resolve-keeps-explicit-nil ()
  "An explicitly supplied nil fills its slot, so it is not truncated."
  (should (equal '("behaviors" nil)
                 (concept--funcall-resolve
                  '("behaviors") '(("relationship" "NIL"))
                  #'concept-funcall-test--ordered))))

(ert-deftest concept-funcall-resolve-pads-interior-gap ()
  (should (equal '("behaviors" nil "law")
                 (concept--funcall-resolve
                  '("behaviors") '(("category" "law"))
                  #'concept-funcall-test--ordered))))

;;;; ---- value conversion -----------------------------------------------

(ert-deftest concept-funcall-nil-literal-satisfies-required ()
  (should (equal '(nil nil nil nil nil)
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--ordered "subject: NIL"))))

(ert-deftest concept-funcall-boolean-literals ()
  (should (equal '(nil t nil nil nil)
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--ordered
                  "subject: FALSE relationship: T"))))

(ert-deftest concept-funcall-numeric-literals ()
  (should (equal '(nil nil nil 2.5 -3)
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--ordered
                  "subject: NIL from: 2.5 count: -3"))))

;;;; ---- brackets -------------------------------------------------------

(ert-deftest concept-funcall-nested-brackets-quote ()
  (should (equal '("{a b c}" "[d e f]")
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--foo-bar
                  "foo: [{a b c}] bar: {[d e f]}"))))

(ert-deftest concept-funcall-bracket-after-colon ()
  (should (equal '("a b" nil)
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--foo-bar "foo:[a b]"))))

(ert-deftest concept-funcall-parens-quote ()
  (should (equal '("x y" nil)
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--foo-bar "foo: (x y)"))))

(ert-deftest concept-funcall-braced-value-is-not-a-keyword ()
  (should (equal '("from: 1" nil)
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--foo-bar "foo: {from: 1}"))))

;;;; ---- &rest ----------------------------------------------------------

(ert-deftest concept-funcall-rest-keyword-absorbs ()
  (should (equal '(3 (4 5 6 7))
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--rest "x: 3 xs: 4 5 6 7"))))

(ert-deftest concept-funcall-rest-keyword-absorbs-braced ()
  (should (equal '(3 ("a b" "c"))
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--rest "x: 3 xs: {a b} c"))))

;;;; ---- prefixes -------------------------------------------------------

(ert-deftest concept-funcall-unambiguous-prefix-matches ()
  (should (equal '("behaviors" nil "law" nil nil)
                 (concept-funcall-with-string-args
                  #'concept-funcall-test--ordered
                  "subject: behaviors cat: law"))))

;;;; ---- parsing on its own ---------------------------------------------

(ert-deftest concept-funcall-parse-splits-positional-from-keywords ()
  (let ((parsed (concept-funcall-parse-string-args
                 "category: law behaviors from: 1 count:3"
                 #'concept-funcall-test--ordered)))
    (should (equal '("behaviors") (car parsed)))
    (should (equal '(("category" "law") ("from" "1") ("count" "3"))
                   (cdr parsed)))))

(ert-deftest concept-funcall-parse-without-a-function ()
  (let ((parsed (concept-funcall-parse-string-args
                 "category: law behaviors from: 1 count:3")))
    (should (equal '("behaviors") (car parsed)))
    (should (equal '(("category" "law") ("from" "1") ("count" "3"))
                   (cdr parsed)))))

;;;; ---- errors ---------------------------------------------------------

(ert-deftest concept-funcall-error-missing-required ()
  (concept-funcall-test--signals
   "Missing required argument `subject'"
   (concept-funcall-with-string-args
    #'concept-funcall-test--ordered "category: law from: 1")))

(ert-deftest concept-funcall-error-empty-string ()
  (concept-funcall-test--signals
   "Missing required argument `subject'"
   (concept-funcall-with-string-args #'concept-funcall-test--ordered "")))

(ert-deftest concept-funcall-error-names-every-missing-required ()
  (concept-funcall-test--signals
   "Missing required arguments `subject', `relationship'"
   (concept-funcall-with-string-args
    #'concept-funcall-test--two-required "")))

(ert-deftest concept-funcall-error-unknown-keyword ()
  (concept-funcall-test--signals
   "Unknown keyword `bogus'"
   (concept-funcall-with-string-args
    #'concept-funcall-test--ordered "subject: x bogus: 3")))

(ert-deftest concept-funcall-error-ambiguous-prefix ()
  (concept-funcall-test--signals
   "Unknown keyword `r'"
   (concept-funcall-with-string-args
    #'concept-funcall-test--ambiguous "subject: x r: 1")))

(ert-deftest concept-funcall-error-keyword-without-value ()
  (concept-funcall-test--signals
   "Missing value for keyword `subject'"
   (concept-funcall-with-string-args
    #'concept-funcall-test--ordered "subject:")))

(ert-deftest concept-funcall-error-keyword-then-keyword ()
  (concept-funcall-test--signals
   "Missing value for keyword `subject'"
   (concept-funcall-with-string-args
    #'concept-funcall-test--ordered "subject: category: law")))

(ert-deftest concept-funcall-error-too-many-positionals ()
  (concept-funcall-test--signals
   "Too many positional arguments"
   (concept-funcall-with-string-args
    #'concept-funcall-test--ordered "a b c d e f")))

(ert-deftest concept-funcall-error-unterminated-bracket ()
  (concept-funcall-test--signals
   "Unterminated"
   (concept-funcall-with-string-args
    #'concept-funcall-test--ordered "subject: {oops")))

;;;; ---- integration with the real target -------------------------------

(ert-deftest concept-funcall-real-target-equivalence ()
  (skip-unless (fboundp 'concept-expand-ordered-relationships))
  (skip-unless
   (concept-funcall-test--named-arglist-p
    (ignore-errors (help-function-arglist
                    #'concept-expand-ordered-relationships t))))
  (should (equal (concept-expand-ordered-relationships "behaviors" nil "law" 1 3)
                 (concept-funcall-with-string-args
                  #'concept-expand-ordered-relationships
                  "category: law behaviors from: 1 count:3"))))

(provide 'concept-funcall-tests)
;;; concept-funcall-tests.el ends here
