;;; concept.el --- Plain-text conceptual knowledge editor for Emacs -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Free Software Foundation, Inc.

;; Author: Kyle Andrews <kyle.c.andrews@gmail.com>, Protesilaos <info@protesilaos.com>
;; Maintainer: Kyle Andrews <kyle.c.andrews@gmail.com>
;; URL: https://github.com/wdkrnls/concept.el
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.1")
;;                    (consult "3.6"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Concept.el is a plain-text conceptual knowledge editor for Emacs.
;; It is based on some of the ideas from the psychologists David
;; Ausibel and Joseph D. Novak who studied how to best learn for
;; understanding. Novak especially focused on exploring how David
;; Ausibel's ideas related to concept maps.
;;
;; Novak-style concept maps can be concstructed using the non-free
;; program: cmaptools (https://cmap.ihmc.us/cmaptools/). His maps
;; focus exclusively on the relationships between abstract
;; concepts. An editor with a traditional graphical user interface
;; like cmaptools seeks only to create an informative diagram as a
;; graphical aid. The details which invite concept formation in the
;; first place are left out. In Novak's conception of concept maps,
;; their use is limited to the reflective period of learning after
;; consuming what Ausibel calls advanced organizers, and potential to
;; the evaluation period. Note that the authors of `concept.el' have
;; never used cmaptools. We are basing our assessment entirely off of
;; the pictures of concept maps produced by that software.
;;
;; This package (concept.el) assumes a far wider role for concept
;; maps. It expects that concept maps will become far larger and more
;; comprehensive than what is feasible to show in a single diagram. It
;; aims to keep concept maps tied to the concrete pieces of knowledge
;; from which we can infer their existence. The core design philosophy
;; holds that the abstract is best understood first by example.
;;
;; Understanding is an iterative process, so as your concept maps grow
;; in complexity, `concept.el' provides powerful tools for sifting
;; through them to support efficient reflection, reorganization, and
;; extension. These include facilities for quickly adding new
;; concepts, relating them to each other, and grounding them in
;; concrete facts, explicit examples, and external references. To keep
;; concept maps from growing unwieldy, there are many tools
;; for probing them from within Emacs. In particular, `concept.el'
;; provides powerful features for searching through related ideas.
;;
;; Concept maps in concept.el are placed in one large file with a
;; `.map' extension. That file follows a specific and regular text
;; format. It contains only plain text, but supports a rich
;; interaction model including a hyper-linking capability (`C-c f')
;; which works for a variety of file formats, both those that are
;; understood by Emacs, and those that are not. The goal of creating
;; concept maps is better understanding and a better memory. Following
;; Ausibel's theory, new understanding comes from integrating new
;; concepts in with old ones. Concepts only integrate with each other
;; through the ideas which jointly leverage them.
;;
;; What are ideas? Ideas propose groups of jointly interesting
;; relationships between concepts. What makes two ideas related? They
;; should have concepts in common, especially their subjects, but also
;; their objects and the relationships between them. Think of an idea
;; as a paragraph, not just any paragraph, but a paragraph focused
;; towards picking out the conceptual aspects of a
;; situation. `concept.el' provides two small query "languages" for
;; finding related ideas. These are presented through live previews
;; via an interface built on top of consult.el.
;;
;; The first query language builds up a list of substrings which
;; should match inside the set of concepts involved in the idea. Each
;; different substring is separated by a semicolon. The second query
;; language is based on subject~relationship~object triples. These
;; enable tighter queries, but their development is necessarily more
;; involved. These features can be discovered by reading the source
;; code, below.
;;
;; There is an example concept map included which is used to
;; illustrate the features of the package and eventually will be used
;; to test many of it features. The search features, especially, need
;; extensive testing.

;;; Code:

(require 'seq)
(require 'outline)
(require 'peg)
(require 'consult)
(require 'imenu)
(require 'man)
(require 'mailcap)
(require 'xml)
(require 'eww)
(require 'ansi-color)

;;; Reference for internal resources

(defconst concept-package-directory
  (or (and load-file-name
           (file-name-directory load-file-name))
      (locate-library "concept")))

;;;; Visual interface to concept maps

(defface concept-subject
  '((t :inherit outline-1 :height 1.2 :weight normal))
  "DEMO face for a heading.")

(defface concept-object
  '((t :inherit default))
  "DEMO face for a heading.")

(defface concept-feature
  '((t :inherit font-lock-string-face))
  "DEMO face for a heading.")

(defface concept-thought
  '((t :inherit shadow))
  "DEMO face for pipes.")

(defface concept-example
  '((t :inherit outline-2 :height 1.2 :weight normal))
  "DEMO face for a heading.")

(defface concept-relationship
  '((t :inherit font-lock-constant-face))
  "DEMO face for a heading.")

(defface concept-attribute
  '((t :inherit default))
  "DEMO face for a heading.")

;; For face names, check `M-x list-faces-display'.
(defconst concept-mode-font-lock-keywords
  '(("^\\(@\\) \\(.*\\)"
     (1 'concept-example)
     (2 'concept-example))
    ("^\\(~\\) \\(.*\\)"
     (1 'concept-subject)
     (2 'concept-subject))
    ("^\\(|\\) \\({.*}\\)"
     (1 'concept-thought)
     (2 'concept-attribute nil :lax-match))
    ("^| \\(.+:\\)"
     (1 'concept-feature nil :lax-match))
    ("^| \\(:.+\\)"
     (1 'concept-relationship nil :lax-match))
    ("^| \\(.+\\)"
     (1 'concept-object nil :lax-match)))
  "Fontification of CONCEPT files.")

(defconst concept-heading-alist
  '(("~" . 1)
    ("@" . 2))
  "Heading symbols for `outline-heading-alist'.")

(defvar concept-subject-or-object-line-regexp
  "^[~|] +[^][:{}‘’ ]+ *$"
  "Regular expression for detecting valid subject or object concepts.")

(defvar concept-object-name-regexp
  "^| +\\([^][:{}‘’ ]+\\) *$"
  "Regular expression for detecting only object concepts.
These are not subject (focus) concepts. They were called data
concepts. They are intimately tied to relationship groups.")

(defvar concept-attribute-group-line-regexp
  "^| +[^][{}‘’ ]+: *$"
  "Regular expression which detects attribute group (keyword) lines.")

(defvar concept-attribute-group-line-lite-regexp
  "^| +[^:]+: *$"
  "Regular expression which detects attribute group (keyword) lines quickly.")

(defvar concept-attribute-group-name-regexp
  "^| +\\([^: ]+\\): *$"
  "Regular expression which detects and extracts attribute group keywords.")

(defvar concept-subject-name-regexp
  "^~ +\\(.+\\) *$"
  "Regular expression for detecting subject concepts.
These are subject concepts. They were called focus concepts.")

(defvar concept-subject-line-regexp
  "^~ +[^: ]+ *$"
  "Regular expression to detect subject lines quickly.")

(defvar concept-object-line-regexp
  "^| +[^][{}‘’: ]+ *$"
  "Regular expression to detect object lines.")

(defvar concept-resource-line-regexp
  "^@ +[^: ]+ *$"
  "Regular expression for detecting what looks like resource lines.")

(defvar concept-relationship-name-regexp
  "^| +:\\([^:~ ]+\\) *$"
  "Regular expression for extracting relationship names.")

(defvar concept-relationship-group-line-regexp
  "^| +:[^][{}‘’ ]+ *$"
  "Regular expression for detecting relationship lines.")

(defvar concept-relationship-group-line-lite-regexp
  "^| +:[^:~ ]+ *$"
  "Regular expression for detecting relationship lines.")

(defvar concept-next-relationship-group-line-regexp
  "^| +:[^ ]+"
  "Regular expression for jumpint to the next relationship line efficiently.")

(defvar concept-next-keyword-line-lite-regexp
  "^| +[^:~ ]+:"
  "Regular expression for jumping to the next relationship line efficiently.")

(defvar concept-attribute-group-keyword-regexp
  "^| +\\([^: ]+\\): *$"
  "Regular expression for detecting keyword lines.")

(defvar concept-resource-name-regexp
  "^@ +\\(.+\\) *$"
  "Regular expression for extracting resource names from resource lines.")

(defvar concept-group-name-restriction-regexp
  "[^][{}‘’:~ ]"
  "Regular expression to match parts of group names or concepts in concept maps.")

(defvar concept-group-name-regexp
  (concat "^[^^: -,;]" concept-group-name-restriction-regexp "+[[:alnum:]]$")
  "Regular expression to match any kind .")

(defun concept--imenu-create-index ()
  "Create an imenu index"
  (let ((concepts      nil)
        (relationships nil)
        (keywords      nil)
        (resources     nil))
    (goto-char (point-min))
    (while (re-search-forward concept-subject-name-regexp nil t)
      (let ((name (string-trim (substring-no-properties (match-string 1)))))
        (unless (assoc name concepts)
          (push (cons name (match-beginning 0)) concepts))))
    (goto-char (point-min))
    (while (re-search-forward concept-object-name-regexp nil t)
      (let ((name (string-trim (substring-no-properties (match-string 1)))))
        (unless (assoc name concepts)
          (push (cons name (match-beginning 0)) concepts))))
    (goto-char (point-min))
    (while (re-search-forward concept-relationship-name-regexp nil t)
      (let ((name (string-trim (substring-no-properties (match-string 1)))))
        (unless (assoc name relationships)
          (push (cons name (match-beginning 0)) relationships))))
    (goto-char (point-min))
    (while (re-search-forward concept-attribute-group-name-regexp nil t)
      (let ((name (string-trim (substring-no-properties (match-string 1)))))
        (unless (assoc name keywords)
          (push (cons name (match-beginning 0)) keywords))))
    (goto-char (point-min))
    (while (re-search-forward concept-resource-name-regexp nil t)
      (let ((name (string-trim (substring-no-properties (match-string 1)))))
        (unless (assoc name resources)
          (push (cons name (match-beginning 0)) resources))))
    (let ((alphabet-sort
           (lambda (a b)
             (string< (downcase (car a))
                      (downcase (car b))))))
      `(("Concepts" . ,(sort concepts alphabet-sort))
        ("Relationships" . ,(sort relationships alphabet-sort))
        ("Keywords"      . ,(sort keywords      alphabet-sort))
        ("Resources"     . ,(sort resources     alphabet-sort))))))

(defun concept--inspect-imenu-index ()
  "Inspect the imenu index by writing it to a temporary buffer"
  (interactive)
  (let ((index-data (concept--imenu-create-index)))
    (with-current-buffer (get-buffer-create "*Concept Imenu Index*")
      (erase-buffer)
      (insert "=== Imenu Index Data ===\n\n")
      (dolist (section index-data)
        (let ((section-name (car section))
              (items (cdr section)))
          (insert (format "--- %s ---\n" section-name))
          (dolist (item items)
            (insert (format "  Name: %S\n  Pos:  %d\n\n" (car item) (cdr item))))
          (insert "\n")))
      (goto-char (point-min)))
    (display-buffer "*Concept Imenu Index*")))

(defun concept-current-line ()
  "Get the current line of text from the buffer."
  (string-trim-right (thing-at-point 'line t)))

(defun concept--concept-word-count (name)
  (with-temp-buffer
    (insert name)
    (count-words (point-min) (point-max))))

(defun concept-word-count ()
  "Count the number of words in the concept name at point."
  (when (concept-on-concept-line)
    (save-excursion
      (end-of-line)
      (re-search-backward "[[:alnum:]]")
      (concept--concept-word-count (thing-at-point 'sexp t)))))

(defun concept-goto-nth-idea (N &optional total)
  "Navigate to the Nth idea in the concept map."
  (when (null total)
    (setq total (concept-map-idea-count)))
  (let ((n total))
    (unless (and (< N n) (<= 0 N))
      (user-error "Supplied indexes are out of range."))
    (concept--goto-first-heading)
    (dotimes (_ N)
      (concept-goto-next-concept-block))))

(defun concept-goto-nth-resource (N &optional total)
  "Navigate to the Nth resource in the relationship block."
  (when (null total)
    (setq total (concept-resource-block-count)))
  (let ((n total))
    (unless (and (< N n) (<= 0 N))
      (user-error "Supplied indexes are out of range."))
    (concept-goto-first-resource-block-in-idea)
    (dotimes (_ N)
      (concept-goto-next-resource))))

(defun concept-goto-nth-relationship-group (N &optional total)
  "Navigate to the Nth relationship group in the relationship block."
  (when (null total)
    (setq total (concept-relationship-group-count)))
  (let ((n total))
    (unless (and (< N n) (<= 0 N))
      (user-error "Supplied indexes are out of range."))
    (concept-goto-first-relationship-group-in-block)
    (dotimes (_ N)
      (concept-goto-next-relationship))))

(defun concept-goto-nth-attribute-group (N &optional total)
  "Navigate to the Nth attribute group in the resource block."
  (when (null total)
    (setq total (concept-resource-keyword-count)))
  (let ((n total))
    (unless (and (< N n) (<= 0 N))
      (user-error "Supplied indexes are out of range."))
    (concept-goto-first-attribute-group-in-block)
    (dotimes (_ N)
      (concept-goto-next-attribute))))

(defun concept-goto-nth-data-concept (N &optional total)
  "Navigate to the Nth data concept in the relationship block."
  (when (null total)
    (setq total (concept-relationship-group-concept-count)))
  (let ((n total))
    (unless (and (< N n) (<= 0 N))
      (user-error "Supplied indexes are out of range."))
    (concept-goto-first-data-concept-in-relationship-group)
    (dotimes (_ N)
      (concept-goto-next-concept))
    (end-of-line)))

(defun concept-goto-nth-exposition-line (N &optional total)
  "Navigate to the Nth data concept in the relationship block."
  (when (null total)
    (setq total (concept-attribute-group-data-count)))
  (let ((n total))
    (unless (and (< N n) (<= 0 N))
      (user-error "Supplied indexes are out of range."))
    (concept-goto-first-exposition-line-in-attribute-group)
    (dotimes (_ N)
      (concept-goto-next-exposition))
    (end-of-line)))

(defun concept-current-idea-index ()
  "Determine the index of the current idea."
  (save-excursion
    (concept-goto-current-focus)
    (let ((i 0))
      (beginning-of-line)
      (while (not (bobp))
        (outline-backward-same-level 1)
        (setq i (1+ i)))
      i)))

(defun concept-move-idea-up (N)
  "Move the current idea up N times."
  (let ((i (concept-current-idea-index)))
    (unless (and (<= 0 N) (< N (1+ i)))
      (user-error "Supplied indexes are out of range."))
    (when (< 0 N)
      (outline-move-subtree-up N))))

(defun concept-move-idea-down (N &optional total)
  "Move the current idea down N times."
  (when (null total)
    (setq total (concept-map-idea-count)))
  (let ((i (concept-current-idea-index))
        (n total))
    (unless (and (<= 0 N) (< N (- n i)))
      (user-error "Supplied indexes are out of range."))
    (when (< 0 N)
      (outline-move-subtree-down N))))

(defun concept-exchange-ideas (i j)
  "Exchange two arbitrary ideas in a concept map."
  (let ((n (concept-map-idea-count)))
    (unless (and (< i n) (< j n)
                 (<= 0 i) (<= 0 j))
      (user-error "Supplied indexes are out of range."))
    (catch 'done
      (cond ((= i j)
             (throw 'done 'identity))
            ((< i j)
             (let ((d (- j i)))
               (concept-goto-nth-idea j n)
               (concept-move-idea-up d)
               (concept-goto-nth-idea (1+ i) n)
               (concept-move-idea-down (1- d) n)))
            (t
             (let ((d (- i j)))
               (concept-goto-nth-idea i n)
               (concept-move-idea-up d)
               (concept-goto-nth-idea (1+ j) n)
               (concept-move-idea-down (1- d) n)))))))

(defun concept-move-resource-down (&optional times)
  "Move the current resource group down."
  (interactive)
  (when (concept-in-resource-block)
    (concept-goto-current-resource)
    (when (null times)
      (setq times 1))
    (when (< times 0)
      (user-error "TIMES must be positive."))
    (dotimes (_ times)
      (outline-move-subtree-down 1))))

(defun concept-move-resource-up (&optional times)
  "Move the current resource group up."
  (interactive)
  (when (concept-in-resource-block)
    (concept-goto-current-resource)
    (when (null times)
      (setq times 1))
    (when (< times 0)
      (user-error "TIMES must be positive."))
    (dotimes (_ times)
      (outline-move-subtree-up 1))))

(defun concept-exchange-resources (i j)
  "Exchange two arbitrary resources under an idea."
  (let ((n (concept-resource-block-count)))
    (unless (and (< i n) (< j n)
                 (<= 0 i) (<= 0 j))
      (user-error "Supplied indexes are out of range."))
    (catch 'done
      (cond ((= i j)
             (throw 'done 'identity))
            ((< i j)
             (let ((d (- j i)))
               (concept-goto-nth-resource j n)
               (concept-move-resource-up d)
               (concept-goto-nth-resource (1+ i) n)
               (concept-move-resource-down (1- d))))
            (t
             (let ((d (- i j)))
               (concept-goto-nth-resource i n)
               (concept-move-resource-up d)
               (concept-goto-nth-resource (1+ j) n)
               (concept-move-resource-down (1- d))))))))

(defun concept-exchange-data-concepts (i j)
  "Exchange two arbitrary data concepts in a relationship group."
  (let ((n (concept-relationship-group-concept-count)))
    (when (< 1 n)
      (unless (and (< i n) (< j n)
                   (<= 0 i) (<= 0 j))
        (user-error "Supplied indexes are out of range."))
      (catch 'done
        (cond ((= i j)
               (throw 'done 'identity))
              ((< i j)
               (let ((d (- j i)))
                 (concept-goto-nth-data-concept j n)
                 (concept-exchange-concept-up d)
                 (concept-goto-nth-data-concept (1+ i) n)
                 (concept-exchange-concept-down (1- d))))
              (t
               (let ((d (- i j)))
                 (concept-goto-nth-data-concept i n)
                 (concept-exchange-concept-up d)
                 (concept-goto-nth-data-concept (1+ j) n)
                 (concept-exchange-concept-down (1- d)))))))))

(defun concept-exchange-attribute-data (i j)
  "Exchange two arbitrary pieces of attribute data in an attribute group."
  (let ((n (concept-attribute-group-data-count)))
    (when (< 1 n)
      (unless (and (< i n) (< j n)
                   (<= 0 i) (<= 0 j))
        (user-error "Supplied indexes are out of range."))
      (catch 'done
        (cond ((= i j)
               (throw 'done 'identity))
              ((< i j)
               (let ((d (- j i)))
                 (concept-goto-nth-exposition-line j n)
                 (concept-exchange-exposition-up d)
                 (concept-goto-nth-exposition-line (1+ i) n)
                 (concept-exchange-exposition-down (1- d))))
              (t
               (let ((d (- i j)))
                 (concept-goto-nth-exposition-line i n)
                 (concept-exchange-exposition-up d)
                 (concept-goto-nth-exposition-line (1+ j) n)
                 (concept-exchange-exposition-down (1- d)))))))))

(defun concept-exchange-relationship-groups (i j)
  "Exchange two arbitrary relationship groups in a relationship block."
  (let ((n (concept-relationship-group-count)))
    (when (< 1 n)
      (unless (and (< i n) (< j n)
                   (<= 0 i) (<= 0 j))
        (user-error "Supplied indexes are out of range."))
      (catch 'done
        (cond ((= i j)
               (throw 'done 'identity))
              ((< i j)
               (let ((d (- j i)))
                 (concept-goto-nth-relationship-group j n)
                 (concept-move-relationship-group-up d)
                 (concept-goto-nth-relationship-group (1+ i) n)
                 (concept-move-relationship-group-down (1- d))))
              (t
               (let ((d (- i j)))
                 (concept-goto-nth-relationship-group i n)
                 (concept-move-relationship-group-up d)
                 (concept-goto-nth-relationship-group (1+ j) n)
                 (concept-move-relationship-group-down (1- d)))))))))

(defun concept-exchange-attribute-groups (i j)
  "Exchange two arbitrary attribute groups in a resource block."
  (let ((n (concept-resource-keyword-count)))
    (when (< 1 n)
      (unless (and (< i n) (< j n)
                   (<= 0 i) (<= 0 j))
        (user-error "Supplied indexes are out of range."))
      (catch 'done
        (cond ((= i j)
               (throw 'done 'identity))
              ((< i j)
               (let ((d (- j i)))
                 (concept-goto-nth-attribute-group j n)
                 (concept-move-attribute-up d)
                 (concept-goto-nth-attribute-group (1+ i) n)
                 (concept-move-attribute-down (1- d))))
              (t
               (let ((d (- i j)))
                 (concept-goto-nth-attribute-group i n)
                 (concept-move-attribute-up d)
                 (concept-goto-nth-attribute-group (1+ j) n)
                 (concept-move-attribute-down (1- d)))))))))

(defun concept-shuffle-ideas ()
  "Randomly shuffle all the ideas in the buffer."
  (interactive)
  (concept--goto-first-heading)
  (let ((n (concept-map-idea-count)))
    (dolist (i (number-sequence 1 (1- n)))
      (let ((j (random i)))
        (concept-exchange-ideas i j))))
  (concept--goto-first-heading))

(defun concept-shuffle-resources ()
  "Randomly shuffle all the ideas in the buffer."
  (interactive)
  (concept-goto-first-resource-block-in-idea)
  (let ((n (concept-resource-block-count)))
    (dolist (i (number-sequence 1 (1- n)))
      (let ((j (random i)))
        (concept-exchange-resources i j))))
  (concept-goto-first-resource-block-in-idea))

(defun concept-randomize-ideas ()
  "Randomly shuffle all the ideas in the buffer.
See also `concept-shuffle' ideas."
  (interactive)
  (when (concept-on-focus-line)
    (concept-shuffle-ideas)))

(defun concept-randomize-resources ()
  "Randomly shuffle all the ideas in the buffer.
See also `concept-shuffle' ideas."
  (interactive)
  (when (concept-on-resource-line)
    (concept-shuffle-resources)))

(defun concept-randomize-data-concepts ()
  "Randomly shuffle all the data concepts in the current relationship block."
  (interactive)
  (when (concept-on-data-concept-line)
    (concept-goto-first-data-concept-in-relationship-group)
    (let ((n (concept-relationship-group-concept-count)))
      (when (< 1 n)
        (dolist (i (number-sequence 1 (1- n)))
          (let ((j (random i)))
            (concept-exchange-data-concepts i j))))
      (concept-goto-first-data-concept-in-relationship-group))))

(defun concept-randomize-attribute-data ()
  "Randomly shuffle all the attribute data in the current attribute group."
  (interactive)
  (when (concept-on-exposition-line)
    (concept-goto-first-exposition-line-in-attribute-group)
    (let ((n (concept-attribute-group-data-count)))
      (when (< 1 n)
        (dolist (i (number-sequence 1 (1- n)))
          (let ((j (random i)))
            (concept-exchange-attribute-data i j))))
      (concept-goto-first-exposition-line-in-attribute-group))))

(defun concept-randomize-relationship-groups ()
  "Randomly shuffle all the relationship groups in the current relationship block."
  (interactive)
  (when (concept-in-relationship-block)
    (concept-goto-first-relationship-group-in-block)
    (let ((n (concept-relationship-group-count)))
      (when (< 1 n)
        (dolist (i (number-sequence 1 (1- n)))
          (let ((j (random i)))
            (concept-exchange-relationship-groups i j))))
      (concept-goto-first-relationship-group-in-block))))

(defun concept-randomize-attribute-groups ()
  "Randomly shuffle all the attribute groups in the current resource block."
  (interactive)
  (when (concept-in-resource-block)
    (concept-goto-first-attribute-group-in-block)
    (let ((n (concept-resource-keyword-count)))
      (when (< 1 n)
        (dolist (i (number-sequence 1 (1- n)))
          (let ((j (random i)))
            (concept-exchange-attribute-groups i j))))
      (concept-goto-first-attribute-group-in-block))))

(defun concept--common-substring-of-length (strings source length)
  "Return a common substring of LENGTH, or nil.
STRINGS should include SOURCE as its first element. SOURCE should be the
shortest string."
  (let ((candidates (make-hash-table :test #'equal))
        (source-length (length source)))
    ;; Initially, every substring of SOURCE is a candidate.
    (dotimes (start (1+ (- source-length length)))
      (puthash (substring source start (+ start length)) t candidates))
    ;; Retain only candidates found in each remaining string.
    (dolist (string (cdr strings))
      (let ((found (make-hash-table :test #'equal))
            (string-length (length string)))
        (when (>= string-length length)
          (dotimes (start (1+ (- string-length length)))
            (let ((part (substring string start (+ start length))))
              (when (gethash part candidates)
                (puthash part t found)))))
        (setq candidates found)))
    ;; Return any surviving candidate.
    (catch 'result
      (maphash
       (lambda (candidate _value)
         (throw 'result candidate))
       candidates)
      nil)))

(defun concept--longest-common-substring (strings)
  "Return a longest substring common to every string in STRINGS.
Comparison is exact and case-sensitive.  Return nil for an empty input
list, and the empty string if no nonempty substring is shared."
  (cond
   ((null strings) nil)
   ((null (cdr strings))
    (car strings))
   (t
    ;; Put the shortest string first, which minimizes candidates.
    (setq strings
          (sort (copy-sequence strings)
                (lambda (a b)
                  (< (length a) (length b)))))
    (let* ((source (car strings))
           (low 0)
           (high (1+ (length source)))
           answer)
      ;; Find the largest length for which a common substring exists.
      (while (< (1+ low) high)
        (let* ((middle (/ (+ low high) 2))
               (candidate
                (concept--common-substring-of-length
                 strings source middle)))
          (if candidate
              (setq low middle
                    answer candidate)
            (setq high middle))))
      (or answer "")))))

(defun concept--closest-buffer-by-longest-common-substring (string)
  "Switch to the buffer with a name containing the longest common substring with string."
  (let* ((lwr (downcase string))
         (bufs (mapcar #'buffer-name (buffer-list)))
         (lcss (mapcar (lambda (x) (length (concept--longest-common-substring (list lwr (downcase x))))) bufs))
         (lbuf (seq-position lcss (seq-max lcss))))
    (nth lbuf bufs)))

(defun concept-switch-to-buffer-with-longest-common-substring (string)
  "Switch to the buffer with a name containing the longest common substring with string."
    (switch-to-buffer (concept--closest-buffer-by-longest-common-substring string)))

(defvar concept-mode-map
  (let ((map (make-sparse-keymap)))
  (define-key map (kbd "M-N")   #'outline-move-subtree-down)
  (define-key map (kbd "M-n")   #'outline-next-visible-heading)
  (define-key map (kbd "C-M-n") #'outline-forward-same-level)
  (define-key map (kbd "M-P")   #'outline-move-subtree-up)
  (define-key map (kbd "C-M-p") #'outline-backward-same-level)
  (define-key map (kbd "M-p")   #'outline-previous-visible-heading)
  map)
  "Keymap for `concept-mode'.
It provides bindings for quickly navigating concepts and examples.")

(define-derived-mode concept-mode text-mode "CONCEPT"
  "Major mode for CONCEPT buffers."
  :keymap concept-mode-map
  ;; Then enable `outline-minor-mode' to start folding the headings.
  (setq-local outline-regexp "^[~@]"
	      outline-heading-alist concept-heading-alist)
  (outline-minor-mode)
  (setq outline-minor-mode-cycle t)
  (setq imenu-generic-expression nil
        imenu-sort-function nil
        imenu-max-items 1000000
        imenu-create-index-function 'concept--imenu-create-index)
  (setq vertico-sort-override '((imenu . nil))
        vertico-sort-override-function 'identity)
  (add-to-list 'completion-category-overrides
        '((imenu (display-sort-function . nil))
          (styles . basic)))
  (run-mode-hooks 'concept-mode-hook)
  (setq-local font-lock-defaults '(concept-mode-font-lock-keywords)))

(add-to-list 'auto-mode-alist '("\\.map\\'" . concept-mode))

;;;; Sorting Concept maps

(defun concept--goto-first-heading ()
  "Go back to the first heading in the region."
  (beginning-of-buffer)
  (condition-case err
      (when (not (concept-on-focus-line))
        (concept-goto-next-concept-block-or-stay))
    (error
     (re-search-forward "^~")
     (beginning-of-line))))

(defun concept--current-heading-text ()
  "Text for the currently selected line.

If there are no lines in the region or if the selected line is
not a heading, then this should return nil."
  (when (outline-on-heading-p)
    (buffer-substring-no-properties
     (line-beginning-position)
     (line-end-position))))

(defun concept--next-heading-text ()
  "Text for the line after this one.

If there is no next heading in the region after the currently
selected line then this will return nil.

(eobp) might be helpful here.
"
  (let ((beginning (point)))
    (save-excursion
      (condition-case nil
	  (outline-forward-same-level 1)
	(error nil))
      (when (and
	     (< beginning (point))
	     (outline-on-heading-p))
	(concept--current-heading-text)))))

(defun concept-next-focus ()
  "Navigate to the next focus block"
  (save-excursion
    (concept-goto-current-focus)
    (condition-case err
        (progn (outline-forward-same-level 1)
               (concept-current-focus))
      (error nil))))

(defun concept-next-resource ()
  "Navigate to the next resource block in the current idea."
  (when (concept-in-resource-block)
    (save-excursion
      (concept-goto-current-resource)
      (condition-case err
          (progn (outline-forward-same-level 1)
                 (concept-current-resource))
        (error nil)))))

(defun concept-map-idea-count ()
  "Count the number of ideas in a concept map."
  (save-excursion
    (beginning-of-buffer)
    (how-many "^~")))

(defun concept-reverse-ideas ()
  "Reverse the order of all the ideas in the buffer."
  (interactive)
  (let ((n (concept-map-idea-count)))
    (when (< 1 n)
      (dotimes (m (1- n))
        (concept--goto-first-heading)
        (dotimes (j (- n m 1))
          (outline-move-subtree-down 1))))))

(defun concept-reverse-data-concepts ()
  "Reverse the order of all the data concepts in the relationship group."
  (interactive)
  (when (and (concept-on-data-line)
             (concept-in-relationship-block))
    (let ((n (concept-relationship-group-concept-count)))
      (when (< 1 n)
        (dotimes (m (1- n))
          (concept-goto-first-data-concept-in-relationship-group)
          (dotimes (j (- n m 1))
            (concept-exchange-concept-down)))))))

(defun concept-reverse-relationship-groups ()
  "Reverse the order of all the relationship groups in the block."
  (interactive)
  (when (concept-on-relationship-line)
    (let ((n (concept-relationship-group-count)))
      (when (< 1 n)
        (dotimes (m (1- n))
          (concept-goto-first-relationship-group-in-block)
          (dotimes (j (- n m 1))
            (concept-move-relationship-group-down)))))))

(defun concept-reverse-attribute-groups ()
  "Reverse the order of all the attribute groups in the resource block."
  (interactive)
  (when (concept-on-attribute-line)
    (let ((n (concept-resource-keyword-count)))
      (when (< 1 n)
        (dotimes (m (1- n))
          (concept-goto-first-attribute-group-in-block)
          (dotimes (j (- n m 1))
            (concept-move-attribute-down)))))))

(defun concept-reverse-resources ()
  "Reverse the order of all the resource blocks included in the current idea."
  (interactive)
  (when (concept-on-resource-line)
    (let ((n (concept-resource-block-count)))
      (when (< 1 n)
        (dotimes (m (1- n))
          (concept-goto-first-resource-block-in-idea)
          (dotimes (j (- n m 1))
            (outline-move-subtree-down 1)))))))

(defun concept-attribute-group-data-count ()
  "Return the number of exposition lines in the current attribute group."
  (cond ((concept-on-attribute-line)
         (length (concept-get-attribute-data)))
        ((concept-on-exposition-line)
         (save-excursion
           (concept-goto-previous-attribute-boundary)
           (end-of-line)
           (length (concept-get-attribute-data))))))

(defun concept-reverse-attribute-data ()
  "Reverse the order of the attribute data included in the current attribute group."
  (interactive)
  (when (concept-on-exposition-line)
    (let ((n (concept-attribute-group-data-count)))
      (when (< 1 n)
        (dotimes (m (1- n))
          (concept-goto-first-exposition-line-in-attribute-group)
          (dotimes (j (- n m 1))
            (concept-exchange-exposition-down)))))))

(defun concept-on-first-relationship-line ()
  "Test if the current position is on the first relationship line in the relationship block."
  (and (concept-on-relationship-line)
       (save-excursion
         (previous-line)
         (concept-on-focus-line))))

(defun concept-on-first-attribute-line ()
  "Test if the current position is on the first attribute line in the resource block."
  (and (concept-on-attribute-line)
       (save-excursion
         (previous-line)
         (concept-on-resource-line))))

(defun concept-reverse-order-dwim (arg)
  "Reverse the order of the thing at point."
  (interactive "P")
  (if (null arg)
      (cond ((concept-on-data-concept-line)
             (concept-reverse-data-concepts))
            ((concept-on-attribute-line)
             (concept-reverse-attribute-groups))
            ((concept-on-exposition-line)
             (concept-reverse-attribute-data))
            ((concept-on-relationship-line)
             (concept-reverse-relationship-groups))
            ((concept-on-resource-line)
             (concept-reverse-resources))
            ((concept-on-focus-line)
             (concept-reverse-ideas)))
    (concept--goto-first-heading)
    (while (not (or (eobp)
                    (concept-on-last-line-p)))
      (when (or (concept-on-first-concept)
                (concept-on-first-relationship-line)
                (concept-on-first-data-concept-line)
                (concept-on-first-attribute-line)
                (concept-on-exposition-line))
        (concept-reverse-order-dwim nil)
        (concept-go-one-group-down)
        (when (and (not (concept-on-last-line-p))
                   (or (concept-current-line-blank-p)
                       (concept-on-blank-line)))
          (user-error "Landed on a blank line in the middle of reversing the order of the file. Aborting!"))))
    (concept--goto-first-heading)))

(defun concept-randomize-dwim (arg)
  "Randomize the order of the thing at point."
  (interactive "P")
  (if (null arg)
      (cond ((concept-on-data-concept-line)
             (concept-randomize-data-concepts))
            ((concept-on-attribute-line)
             (concept-randomize-attribute-groups))
            ((concept-on-relationship-line)
             (concept-randomize-relationship-groups))
            ((concept-on-resource-line)
             (concept-randomize-resources))
            ((concept-on-exposition-line)
             (concept-randomize-attribute-data))
            ((concept-on-focus-line)
             (concept-randomize-ideas)))
    (concept--goto-first-heading)
    (concept-randomize-dwim nil)
    (while (not (or (eobp)
                    (concept-on-last-line-p)))
      (when (and (not (concept-on-focus-line))
                 (or (concept-on-first-relationship-line)
                     (concept-on-first-data-concept-line)
                     (concept-on-first-attribute-line)
                     (concept-on-exposition-line)))
        (concept-randomize-dwim nil))
      (concept-go-one-group-down)
      (when (and (not (concept-on-last-line-p))
                 (or (concept-current-line-blank-p)
                     (concept-on-blank-line)))
        (user-error "Landed on a blank line in the middle of randomizing the file. Aborting!")))
    (concept--goto-first-heading)))

(defun concept-string-lessp-with-length-tie-break (a b &optional length-a length-b)
  "Test of A is less than B in terms of lexicographic (alphabetic) order.
By default the length of a section is the number of characters which are needed to represent it."
  (when (null length-a)
    (setq length-a 0))
  (when (null length-b)
    (setq length-b 0))
  (or (string< a b)
      (and (string= a b)
           (< length-a length-b))))

(defun concept-idea-length ()
  "Compute the number of characters in the current idea."
  (save-excursion
    (concept-goto-current-focus)
    (let ((beg (line-beginning-position)))
      (outline-end-of-subtree)
      (let ((end (point)))
        (- end beg)))))

(defun concept-next-idea-length ()
  "Compute the number of characters in the next idea."
  (save-excursion
    (concept-goto-next-focus)
    (concept-idea-length)))

(defun concept-resource-length ()
  "Compute the number of characters in the current resource."
  (when (concept-in-resource-block)
    (save-excursion
      (concept-goto-current-resource)
      (let ((beg (line-beginning-position)))
        (outline-end-of-subtree)
        (let ((end (point)))
          (- end beg))))))

(defun concept-next-resource-length ()
  "Compute the number of characters in the current resource."
  (when (concept-in-resource-block)
    (save-excursion
      (concept-goto-current-resource)
      (condition-case no-more-resources
          (progn
            (outline-forward-same-level 1)
            (end-of-line)
            (concept-resource-length))
        (error nil)))))

(defun concept-relationship-group-length ()
  "Compute the number of characters in the current relationship group."
  (when (or (concept-on-data-concept-line)
            (concept-on-relationship-line))
    (save-excursion
      (when (concept-on-data-concept-line)
        (concept-goto-last-relationship))
      (let ((beg (line-beginning-position)))
        (forward-line)
        (concept-goto-next-relationship-boundary)
        (backward-char)
        (let ((end (point)))
          (- end beg))))))

(defun concept-next-relationship-group-length ()
  "Compute the number of characters in the next relationship group."
  (when (or (concept-on-data-concept-line)
            (concept-on-relationship-line))
    (save-excursion
      (concept-goto-next-relationship-boundary)
      (when (concept-on-relationship-line)
        (concept-relationship-group-length)))))

(defun concept-attribute-group-length ()
  "Compute the number of characters in the current attribute group."
  (when (or (concept-on-exposition-line)
            (concept-on-attribute-line))
    (save-excursion
      (when (concept-on-exposition-line)
        (concept-goto-last-attribute))
      (let ((beg (line-beginning-position)))
        (forward-line)
        (concept-goto-next-attribute-boundary)
        (backward-char)
        (let ((end (point)))
          (- end beg))))))

(defun concept-next-attribute-group-length ()
  "Compute the number of characters in the next attribute group."
  (when (or (concept-on-exposition-line)
            (concept-on-attribute-line))
    (save-excursion
      (concept-goto-next-attribute-boundary)
      (when (concept-on-attribute-line)
        (concept-attribute-group-length)))))

(defun concept-data-concept-length ()
  "Compute the number of characters in the current data concept."
  (when (concept-on-data-concept-line)
    (length (concept-current-concept))))

(defun concept-exposition-length ()
  "Compute the number of characters in the current relationship group."
  (when (concept-on-exposition-line)
    (length (concept-current-exposition))))

(defun concept-next-exposition-length ()
  "Compute the number of characters in the current relationship group."
  (when (concept-on-exposition-line)
    (save-excursion
      (forward-line)
      (when (concept-on-exposition-line)
        (concept-exposition-length)))))

(defun concept-next-data-concept-length ()
  "Compute the number of characters in the next data concept."
  (when (concept-on-data-concept-line)
    (save-excursion
      (forward-line)
      (when (concept-on-data-concept-line)
        (concept-data-concept-length)))))

(defvar concept-large-concept-map-idea-threshold
  500
  "Threshold for deciding if a concept map is big or not.
Ideas in large concept map probably cannot be sorted efficiently using
bubble sort.")

(defvar concept-map-bubble-sort-maximum-iterations
  10001
  "Default maximum iterations for bubble sort.")

(defun concept-idea-partial-sort (&optional max-iter)
    "Interactive tool for automatically reordering concepts or examples.
This clears the buffer undo history, so please be careful when you do
this!

Emacs provides `outline-forward-same-level' and
`outline-move-subtree-down' procedures out of the box. These are enough
to implement a naive sorting algorithm for interactively reordering
concepts in lexicographic order."
  (interactive)
  (setq max-iter (or max-iter concept-map-bubble-sort-maximum-iterations))
  (concept--goto-first-heading)
  (let ((result
         (let ((swapped nil)
               (n (concept-map-idea-count))
               (buffer-undo-list t)
               (iter max-iter))
           (when (<= concept-large-concept-map-idea-threshold n)
             (message "This is a large map with %d ideas. Undo history will be cleared." n))
           (catch 'done
             (while (< 0 iter)
               (let ((a        (concept-current-focus))
                     (length-a (concept-idea-length))
                     (b        (concept-next-focus))
                     (length-b (concept-next-idea-length)))
                 (cond
                  ((or (null a) (null b))
                   (if (null swapped)
                       (throw 'done
                              (list 'sorted (- max-iter iter) n))
                     (setq swapped nil)
                     (concept--goto-first-heading)))
                  ((concept-string-lessp-with-length-tie-break
                    a b length-a length-b)
                   (outline-forward-same-level 1))
                  (t
                   (setq swapped t)
                   (outline-move-subtree-down 1))))
               (setq iter (1- iter)))
             (list 'iterations-exhausted (- max-iter iter) n)))))
    (when (<= concept-large-concept-map-idea-threshold (nth 2 result))
      (setq buffer-undo-list nil))
    (pcase (car result)
      ('sorted
       (message
        "Bubble sort completed in %d iterations on %d ideas."
        (nth 1 result)
        (nth 2 result)))
      ('iterations-exhausted
       (message
        "Bubble sort stopped after %d iterations on %d ideas."
        (nth 1 result)
        (nth 2 result))))))

(defun concept-resource-partial-sort (&optional max-iter)
  "Interactive tool for automatically reordering resource blocks.

Emacs provides `outline-forward-same-level' and
`outline-move-subtree-down' procedures out of the box. These are
enough to implement a naive sorting algorithm for interactively
reordering resource blocks alphabetically."
  (interactive)
  (when (null max-iter)
    (setq max-iter concept-map-bubble-sort-maximum-iterations))
  (let ((n (concept-resource-block-count)))
    (catch 'done
      (cond ((< n 2)
             (throw 'done 'sorted))
            (t
             (concept-goto-first-resource-block-in-idea)
             (let ((swapped nil))
               (while (< 0 max-iter)
                 (let ((a (concept-current-resource))
                       (length-a (concept-resource-length))
	               (b (concept-next-resource))
                       (length-b (concept-next-resource-length)))
                   (cond
                    ((null b)
                     (when (null swapped)
                       (throw 'done 'sorted))
                     (setq swapped nil)
	             (concept-goto-first-resource-block-in-idea))
                    ((concept-string-lessp-with-length-tie-break a b length-a length-b)
                     (outline-forward-same-level 1))
                    (t
                     (setq swapped t)
	             (outline-move-subtree-down 1))))
                 (setq max-iter (1- max-iter)))
               (throw 'done 'iterations-exhausted)))))))

(defun concept-goto-first-data-concept-in-relationship-group ()
  "Navigate back to the first data concept in the group."
  (when (and (concept-in-relationship-block)
             (concept-on-data-line))
    (when (concept-on-data-concept-line)
      (concept-goto-last-relationship))
    (forward-line)))

(defun concept-data-concept-partial-sort (&optional max-iter)
  "Interactive tool for automatically reordering concepts.
The commands `concept-exchange-concept-up' and
`concept-exchange-concept-down' are enough to implement a naive sorting
algorithm for interactively reordering concepts seeking a canonical
ordering. A canonical ordering is useful for avoiding semantically
spurious diffs, e.g., in commits to version control systems. It is also
useful for reducing the difficulty of refactoring concept maps. It
places ideas with similar names next to each other."
  (interactive "P")
  (when (and (concept-in-relationship-block)
             (not (concept-on-focus-line))
             (or (< 1 (concept-relationship-group-concept-count))
                 (end-of-line)))
    (when (null max-iter)
      (setq max-iter concept-map-bubble-sort-maximum-iterations))
    (concept-goto-first-data-concept-in-relationship-group)
    (let ((line (line-number-at-pos (point))))
      (catch 'done
        (let ((i 0)
              (swapped nil))
          (while (< i max-iter)
            (let ((a (concept-current-concept))
                  (length-a (concept-data-concept-length))
	          (b (concept-next-data-concept))
                  (length-b (concept-next-data-concept-length)))
              (cond
               ((concept-on-last-line-in-block-p)
                (when (null swapped)
                  (throw 'done 'sorted))
                (setq swapped nil)
                (concept-goto-first-data-concept-in-relationship-group))
               ((concept-string-lessp-with-length-tie-break a b length-a length-b)
	        (concept-goto-next-data-concept))
               (t
                (setq swapped t)
	        (concept-exchange-concept-down))))
            (setq i (1+ i)))))
      (goto-line line)
      (end-of-line))))

(defun concept-exposition-partial-sort (&optional max-iter)
  "Interactive tool for automatically reordering concepts.
The commands `concept-exchange-exposition-up' and
`concept-exchange-exposition-down' are enough to implement a naive
sorting algorithm for interactively reordering concepts seeking a
canonical ordering. A canonical ordering is useful for avoiding
semantically spurious diffs, e.g., in commits to version control
systems. It is also useful for reducing the difficulty of refactoring
concept maps. It places ideas with similar names next to each other."
  (interactive "P")
  (when (and (concept-in-resource-block)
             (not (concept-on-resource-line))
             (or (< 1 (concept-attribute-group-data-count))
                 (end-of-line)))
    (when (null max-iter)
      (setq max-iter concept-map-bubble-sort-maximum-iterations))
    (concept-goto-first-exposition-line-in-attribute-group)
    (let ((line (line-number-at-pos (point))))
      (catch 'done
        (let ((i 0)
              (swapped nil))
          (while (< i max-iter)
            (let ((a (concept-current-exposition))
                  (length-a (concept-exposition-length))
	          (b (concept-next-exposition))
                  (length-b (concept-next-exposition-length)))
              (cond
               ((concept-on-last-line-in-block-p)
                (when (null swapped)
                  (throw 'done 'sorted))
                (setq swapped nil)
                (concept-goto-first-exposition-line-in-attribute-group))
               ((concept-string-lessp-with-length-tie-break a b length-a length-b)
	        (concept-goto-next-exposition))
               (t
                (setq swapped t)
	        (concept-exchange-exposition-down))))
            (setq i (1+ i)))))
      (goto-line line)
      (end-of-line))))

(defun concept--split-string-by-bare-tilde (str)
  "Split STR by ~, but don't split at ~ inside [~]."
  (let ((result '())
        (current "")
        (in-brackets nil)
        (i 0))
    (while (< i (length str))
      (let ((char (substring str i (1+ i))))
        (cond
          ;; Toggle bracket state
          ((string= char "[")
           (setq in-brackets t)
           (setq current (concat current char)))
          ((string= char "]")
           (setq in-brackets nil)
           (setq current (concat current char)))
          ;; Split only if separator and NOT in brackets
          ((and (string= char "~") (not in-brackets))
           (push current result)
           (setq current ""))
          ;; Otherwise accumulate
          (t
           (setq current (concat current char))))
        (setq i (1+ i))))
    ;; Don't forget the last part
    (push current result)
    (reverse result)))

(defun concept-add-concept ()
  "Add new concept line to a concept map file."
  (interactive)
  (beginning-of-line)
  (open-line 1)
  (insert "~ "))

(defun concept-add-data ()
  "Add new line of data to a concept map file."
  (interactive)
  (beginning-of-line)
  (open-line 1)
  (insert "| "))

(defun concept-current-line-empty-p ()
  "Check whether the current line is blank."
  (save-excursion
    (beginning-of-line)
    (looking-at-p "[[:blank:]]*$")))

(defun concept-add-new-data ()
  "Add new line of data to a concept map below the current line.

Note: see also `concept-add-data-below' which I wrote after forgetting
this."
  (interactive)
  (when (not (concept-current-line-empty-p))
    (next-line))
  (beginning-of-line)
  (open-line 1)
  (insert "| "))

(defun concept-on-last-line-p ()
  (save-excursion
    (end-of-line)
    (= (point) (point-max))))

(defun concept-on-first-line-p ()
  (= 1 (line-number-at-pos (point))))

(defun concept-on-first-concept ()
  "Test if the concept is the first concept in the file."
  (and (concept-on-focus-line)
       (save-excursion
         (beginning-of-line)
         (not (re-search-backward "^~" nil t)))))

(defun concept-on-last-concept ()
  "Test if the concept is the first concept in the file."
  (and (concept-on-concept-line)
       (save-excursion
         (end-of-line)
         (not (re-search-forward "^[~|]" nil t)))))

(defun concept-on-data-line ()
  "Test if the current line is a data line.
A data line starts with a vertical bar."
  (string-match-p "^|" (concept-current-line)))

(defun concept-on-blank-line ()
  "Test if the current line is a partially blank line.
This still expects it to be part of the concept.el world. This differs
from `concept-current-line-blank-p' in that it expects a concept map
line with a prefix character like `|' or `@' or `~'. That other one
would work on any buffer with trailing blank characters."
  (string-match-p "^[|@~] *$" (concept-current-line)))

(defun concept-last-concept ()
  "Get the last concept before the current position if on a data line."
  (let ((is-data (concept-on-data-line))
        (is-focus (concept-on-focus-line)))
    (if is-data
      (save-excursion
        (re-search-backward "^~")
        (beginning-of-line)
        (forward-char 2)
        (buffer-substring-no-properties (point) (line-end-position)))
      (when is-focus
        (save-excursion
          (while (not (and (concept-in-relationship-block)
                           (concept-on-data-line)))
            (re-search-backward "^| ")
            (beginning-of-line))
          (when (concept-on-data-line)
            (forward-char 2)
            (buffer-substring-no-properties (point) (line-end-position))))))))

(defun concept-last-relationship ()
  "Get the last concept before the current position if on a data line."
  (let ((is-data (concept-on-data-line))
        (in-block (concept-in-relationship-block)))
    (when (and is-data in-block)
      (save-excursion
        (when (re-search-backward ":[^ ]+" nil t)
          (beginning-of-line)
          (re-search-forward ":")
          (string-trim (buffer-substring-no-properties (point) (line-end-position))))))))

(defun concept-next-relationship ()
  "Get the last concept before the current position if on a data line."
  (let ((is-data (concept-on-data-line))
        (in-block (concept-in-relationship-block)))
    (when (and is-data in-block)
      (save-excursion
        (when (re-search-forward "^| :[^ ]+" nil t)
          (re-search-backward ":")
          (forward-char)
          (string-trim (buffer-substring-no-properties (point) (line-end-position))))))))

(defun concept-next-concept (&optional arg)
  "Get the next concept from the current position if on a data line.
This procedure takes an option argument ARG which advances multiple concepts at a time."
  (when (not arg)
    (setq arg 1))
  (when (and (concept-in-relationship-block)
             (or (concept-on-focus-line)
                 (concept-on-data-line)))
    (save-excursion
      (let ((i 0)
            (conc nil))
        (while (< i arg)
          (when (re-search-forward "^~" nil t)
            (setq i (1+ i))
            (forward-char 1)
            (setq conc (buffer-substring-no-properties (point) (line-end-position)))))
        conc))))

(defun concept-last-data-concept ()
  "Get the last concept before the current position if on a data line."
  (when (concept-in-relationship-block)
    (save-excursion
      (previous-line)
      (beginning-of-line)
      (when (and (not (concept-on-relationship-line)))
        (forward-char 2)
        (buffer-substring-no-properties (point) (line-end-position))))))

(defun concept-last-data-concept ()
  "Get the last concept before the current position if on a data line."
  (cond ((concept-in-resource-block)
         (save-excursion
           (concept-goto-current-focus)
           (concept-goto-next-resource)
           (previous-line)
           (end-of-line)
           (concept-current-concept)))
        ((concept-in-relationship-block)
         (save-excursion
           (previous-line)
           (beginning-of-line)
           (when (and (not (concept-on-relationship-line)))
             (forward-char 2)
             (buffer-substring-no-properties (point) (line-end-position)))))))

(defun concept-insert-concept-as-data ()
  "Repeat the current concept in focus as a data concept."
  ;; TODO: Document the difference between this and the -2 variant
  (interactive)
  (let ((last-concept (concept-last-concept)))
    (when last-concept
      (when (concept-on-data-line)
        (insert last-concept)))))

(defun concept-insert-focus-as-new (arg)
  "Repeat the current concept in focus as a data concept."
  (interactive "P")
  (let* ((last-concept (if (or (concept-on-first-line-p)
                               (concept-on-first-concept))
                           (concept-next-concept)
                         (concept-last-concept)))
         (k            (if (numberp arg) arg 0))
         (last-part    (concept-remove-part last-concept k)))
    (when last-concept
      (when (or (concept-on-data-line)
                (concept-on-focus-line))
        (insert last-part)))))

(defun concept-insert-next-concept-as-data ()
  "Repeat the current concept in focus as a data concept."
  (interactive)
  (let ((next-concept (concept-next-concept)))
    (when next-concept
      (end-of-line)
      (insert next-concept))))

(defun concept-insert-next-concept-as-data-2 (arg)
  "Repeat the current concept in focus as a data concept."
  (interactive "P")
  (let ((next-concept (concept-next-concept))
        (k (if (numberp arg) arg 0)))
    (when next-concept
      (let ((next-part (concept-remove-part next-concept k)))
        (end-of-line)
        (insert next-part)))))

(defun concept-insert-concept-after-next-as-data ()
  "Repeat the current concept in focus as a data concept."
  (interactive)
  (let ((next-concept (concept-next-concept)))
    (when next-concept
      (end-of-line)
      (insert next-concept))))

(defun concept-insert-last-concept-as-focus ()
  "Insert the last concept mentioned into the current focus."
  (interactive)
  (let ((last-concept (concept-last-concept)))
    (when last-concept
      (end-of-line)
      (insert last-concept))))

(defun concept-insert-last-concept-as-focus-2 (arg)
  "Insert the last concept mentioned into the current focus."
  (interactive "P")
  (let ((last-concept (concept-last-concept))
        (k            (if (numberp arg) arg 0)))
    (when last-concept
      (let ((last-part    (concept-remove-part last-concept k)))
        (end-of-line)
        (insert last-part)))))

(defun concept-insert-next-concept-as-focus (arg)
  "Insert the next concept mentioned into the current focus."
  (interactive "P")
  (let ((next-concept (concept-next-concept))
        (k            (if (numberp arg) arg 0)))
    (when next-concept
      (let ((next-part    (concept-remove-part next-concept k)))
        (end-of-line)
        (insert next-part)))))

(defun concept-insert-last-concept-as-data ()
  "Repeat the last related data concept again as the starting text
for a new data concept

This happens in two ways:

1. When the line is currently blank then it inserts the previous
   concept leaving the cursor at the beginning.
2. When the line already has text, then it inserts the previous
   concept at the current point.

Note that I am not currently checking that the current point is valid.
That is up to the user at the moment!"
  (interactive)
  (let ((last-concept (concept-last-data-concept)))
    (when last-concept
      (let ((is-blank-line (concept-on-blank-line)))
        (when is-blank-line
          (end-of-line)
          (insert last-concept)
          (search-backward " ")
          (forward-char 1))
        (when (not is-blank-line)
          (insert last-concept))))))

(defun concept-remove-part (concept n)
  "Remove part of a concept following the convention."
  (let* ((parts (string-split concept "-" t " +"))
         (k     (length parts)))
    (if (or (eq n 0) (<= k (abs n)))
        concept
      (if (< n 0)
          (string-join (take (abs n) parts) "-")
        (string-join (reverse (take n (reverse parts))) "-")))))

(defun concept-insert-last-concept-as-new (arg)
  "Repeat the last related data concept again as the starting text
for a new concept.

This happens in two ways:

1. When the line is currently blank then it inserts the previous
   concept leaving the cursor at the beginning.
2. When the line already has text, then it inserts the previous
   concept at the current point.

Note that I am not currently checking that the current point is valid.
That is up to the user at the moment!

This version takes an optional argument for number to insert just the
tail end of the match. This can be helpful in some situations. It also
gives some leniency in the case you are editing a 'new' first data
concept in a relationship group where you already had another one
previously. In that case the command inserts the next data concept and
calls it the last data concept. Since this function is only used for
interactive editing by a user, this makes sense."
  (interactive "P")
  (let* ((last-concept (or (and (concept-on-first-concept)
                                (concept-next-focus))
                           (concept-last-data-concept)
                           (or (and (< 1 (concept-relationship-group-concept-count))
                                    (if (concept-on-last-concept)
                                        (concept-last-concept)
                                      (concept-next-data-concept)))
                               (concept-next-focus))))
         (k            (if (numberp arg) arg 0)))
    (when last-concept
      (let ((is-blank-line (concept-on-blank-line))
            (last-part (concept-remove-part last-concept k)))
        (when is-blank-line
          (end-of-line)
          (insert last-part)
          (search-backward " ")
          (forward-char 1))
        (when (not is-blank-line)
          (insert last-part))))))

(defun concept-repeat-current-block ()
  "Repeat the current block again."
  (interactive)
  (save-excursion
    (outline-next-visible-heading 1)
    (beginning-of-line)
    (backward-char)
    (let ((p (point)))
      (re-search-backward "^~")
      (kill-ring-save (point) p)
      (goto-char p)
      (newline)
      (yank))))

(defun concept-current-line-blank-p ()
  "Test if the current line is a blank line."
  (save-excursion
    (beginning-of-line)
    (looking-at-p "^[[:blank:]]*$")))

(defun concept-repeat-concept-as-focus ()
  "Repeat the current data concept as a focus concept.

This considers two distinct situations. Either the current line is the
last line in the current block, or it is not. If it is the last line,
then move down a line and yank the current relationship there. If it is
not the last line, then navigate to the next focus concept, go back a
line and then place the new focus concept before it. There is a slight
rub here as it's very possible for new concept maps to be editing the
last relationship block: in which case there is not next focus
concept. In that case, navigate to the last line and the file and if it
is blank, insert it. Otherwise, make a new line and insert it."
  (interactive)
  (let ((line-move-visual nil))
    (when (and
           (concept-in-relationship-block)
           (concept-on-data-line)
           (not (concept-on-relationship-line)))
      (beginning-of-line)
      (kill-ring-save (point) (line-end-position))
    ;;; When on the last line we make a new line
      (when (concept-in-relationship-block)
        (let ((has-next-focus (re-search-forward "^~" nil t)))
          (when (not has-next-focus)
            (end-of-line)
            (while (not (concept-current-line-blank-p))
              (if (concept-on-last-line-p)
                  (newline)
                (progn
                  (next-line)
                  (end-of-line)))))))
      (previous-line)
      (end-of-line)
      (newline)
      (yank)
      (beginning-of-line)
      (delete-char 1)
      (insert "~")
      (end-of-line))))

(defun concept-repeat-focus-concept ()
  "Repeat the current focus concept on the next line."
  (interactive)
  (let ((line-move-visual nil))
    (when (concept-on-focus-line)
      (beginning-of-line)
      (kill-ring-save (point) (line-end-position))
      (end-of-line)
      (let ((has-next-focus (re-search-forward "^~" nil t)))
        (when (not has-next-focus)
          (while (not (concept-current-line-blank-p))
            (if (concept-on-last-line-p)
                (newline)
              (next-line)))))
      (previous-line)
      (end-of-line)
      (newline)
      (yank)
      (beginning-of-line)
      (delete-char 1)
      (insert "~")
      (end-of-line))))

(defun concept-repeat-dwim ()
  "Repeat what I mean to repeat.
This largely operates below the current line."
  (interactive)
  (cond ((concept-on-focus-line)
         (concept-repeat-focus-concept))
        ((concept-on-relationship-line)
         (re-search-backward "^~" nil t)
         (concept-repeat-focus-concept))
        ((concept-on-exposition-line)
         (if (string= "question" (concept-current-attribute))
             (concept-insert-keyword-block "answer")
           (concept-insert-note-block)))
        ((concept-on-resource-line)
         (let ((resource (concept-current-resource)))
           (outline-end-of-subtree)
           (newline)
           (insert "@ " resource)))
        ((concept-on-attribute-line)
         (outline-end-of-subtree)
         (concept-insert-note-block))
        (t
         (concept-repeat-concept-as-focus))))

(defun concept-add-data-below ()
  "Add a new data line above the current line."
  (interactive)
  (when (and (concept-on-data-line)
             (not (concept-on-relationship-line))
             (not (concept-on-attribute-line)))
    (end-of-line)
    (newline)
    (insert "| ")))

(defun concept-add-dwim ()
  "Add what I mean to add.
This largely operates above the current line."
  (interactive)
  (beginning-of-line)
  (let ((p (thing-at-point 'symbol t)))
    (cond ((concept-on-resource-line)
           (previous-line)
           (end-of-line)
           (newline)
           (insert "| "))
     ((concept-in-relationship-block)
           (if (equal "|" p)
               (concept-add-data)
             (concept-add-concept)))
          ((and (concept-in-resource-block)
                (save-excursion
                  (previous-line)
                  (concept-on-resource-line)))
           (previous-line)
           (end-of-line)
           (concept-insert-note-block))
          ((and (concept-in-resource-block)
                (concept-on-data-line))
           (concept-add-data)
           (insert "{}")
           (backward-char))
          (t (concept-add-data)))))

(defun concept-toggle-attribute-relationship ()
  "Toggle between an attribute and a relationship.
An attribute has a colon at the end of the statement. A
relationship has a colon at the beginning of the statement."
  (when (concept-on-data-line)
    (save-excursion
    (let ((is-relationship (concept-on-relationship-line))
          (is-attribute (concept-on-attribute-line))
          (beg (line-beginning-position))
          (end (line-end-position)))
      (when is-relationship
        (replace-regexp-in-region ":" "" beg end)
        (end-of-line)
        (insert ":")
        (replace-regexp-in-region " +:" ":" beg end))
      (when is-attribute
        (replace-regexp-in-region ":" "" beg end)
        (replace-regexp-in-region "[|] *" "| :" beg end))))))

(defun concept-toggle-focus-data ()
  "Toggle between concept focus and data in a concept map file."
  (when (or
         (= 1 (line-number-at-pos (point)))
         (concept-in-relationship-block))
    (save-excursion
      (beginning-of-line)
      (if (concept-current-line-blank-p)
          (insert "|")
        (let ((p (string (char-after (point)))))
          (if (equal "|" p)
              (progn
                (delete-char 1)
                (insert "~"))
            (progn
              (delete-char 1)
              (insert "|"))))))))

(defun concept-on-attribute-or-relationship-line ()
  "Test if the current line is an attribute or relationship line."
  (or (concept-on-attribute-line)
      (concept-on-relationship-line)))

(defun concept-toggle-context ()
  (interactive)
  (save-excursion
    (if (concept-on-attribute-or-relationship-line)
        (concept-toggle-attribute-relationship)
      (concept-toggle-focus-data))))

(defun concept-cycle-context-0 ()
  "Rotate the sigil used to identify the meaning of the line in a concept map file."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (let ((p (thing-at-point 'symbol t)))
      (cond ((equal "|" p)
             (delete-char 1)
             (insert "~"))
            ((equal "~" p)
             (delete-char 1)
             (insert "@"))
            ((equal "@" p)
             (delete-char 1)
             (insert "|"))))))

(defun concept-cycle-context ()
  "Rotate the sigil used to identify the meaning of the line in a concept map file."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (let ((beg (line-beginning-position))
          (end (line-end-position))
          (fst (string (char-after (line-beginning-position)))))
      (when (or (concept-on-focus-line)
                (and (concept-on-data-line) (concept-on-concept-line))
                (concept-on-resource-line)
                (and (concept-in-resource-block)
                     (concept-on-data-line)
                     (or (concept-on-blank-line)
                         (concept-on-concept-or-resource-looking-line))))
        (cond ((equal "|" fst)
               (delete-char 1)
               (insert "@"))
              ((equal "~" fst)
               (delete-char 1)
               (insert "|"))
              ((equal "@" fst)
               (delete-char 1)
               (insert "~"))
              (t
               (insert "|")
               (newline))))
      (when (concept-on-exposition-line)
        (concept-cycle-expression-brackets)))))

(defun concept-cycle-expression-brackets ()
  "Rotate the brackets used to express the exposition."
  (interactive)
  (when (concept-on-exposition-line)
    (save-excursion
      (beginning-of-line)
      (re-search-forward "[[{‘]" (line-end-position) t)
      (backward-char)
      (let ((opening-bracket (string (char-after (point)))))
        (when (equal opening-bracket "{")
          (replace-regexp-in-region "| +{" "| [" (line-beginning-position) (line-end-position))
          (replace-regexp-in-region "} *$" "]" (line-beginning-position) (line-end-position)))
        (when (equal opening-bracket "[")
          (replace-regexp-in-region "| +\\[" "| ‘" (line-beginning-position) (line-end-position))
          (replace-regexp-in-region "\\] *$" "’" (line-beginning-position) (line-end-position)))
        (when (equal opening-bracket "‘")
          (replace-regexp-in-region "| +‘" "| {" (line-beginning-position) (line-end-position))
          (replace-regexp-in-region "’ *$" "}" (line-beginning-position) (line-end-position)))))))

(defun concept-insert-include-line ()
  "Insert an include line.
Such lines go inside a relationship block."
  (when (concept-in-relationship-block)
    (concept-add-new-data)
    (insert ":include")))

(defun concept-insert-relationship-line (relationship)
  "Insert a relationship line.
Such lines go inside a relationship block."
  (when (concept-in-relationship-block)
    (concept-add-new-data)
    (insert (format ":%s" relationship))))

(defun concept-insert-keyword-line (name)
  "Insert a keyword attribute.
An attribute ends with a colon and is only appropriate when
inside a resource block."
  (when (concept-in-resource-block)
    (unless (string-match-p concept-group-name-regexp name)
      (user-error "%s is not a valid keyword name!" name))
    (concept-add-new-data)
    (insert (concat name ":"))))

(defun concept-insert-note-line ()
  "Insert a note attribute.
An attribute ends with a colon and is only appropriate when
inside a resource block."
  (when (concept-in-resource-block)
    (concept-add-new-data)
    (insert "note:")))

(defun concept-on-focus-line ()
  "Test if the current line is a concept focus line."
  (save-excursion
    (beginning-of-line)
    (looking-at "^~")))

(defun concept-on-concept-line ()
  "Test if the current line is a concept line."
  (and (not (concept-in-resource-block))
       (or (concept-on-focus-line)
           (and (concept-on-data-line)
                (not (concept-on-relationship-line))))))

(defun concept-on-concept-or-resource-looking-line ()
  "Test if the current line looks like a concept line."
  (let ((line (concept-current-line)))
    (string-match-p (concat "^[@|~] +" concept-group-name-restriction-regexp) line)))

(defun concept-on-resource-line ()
  "Test if the current line is a resource line.
A resource line starts with an `@' symbol."
  (save-excursion
    (beginning-of-line)
    (string-match-p
     "^[@]"
     (buffer-substring-no-properties
      (point) (min (+ 1 (point)) (line-end-position))))))

(defun concept-in-resource-block ()
  "Test if we are inside a resource block."
  (or
   (concept-on-resource-line)
   (and (concept-on-data-line)
        (save-excursion
          (ignore-errors
            (outline-up-heading 0)
            (concept-on-resource-line))))))

(defun concept-in-relationship-block ()
  "Test if we are inside a relationship block."
  (or
   (concept-on-focus-line)
   (save-excursion
     (re-search-backward "^[~@]")
     (concept-on-focus-line))))

(defun concept-on-relationship-line ()
  "Test if the current line is a relationship line."
  (and (not (concept-on-exposition-line))
       (let ((line (concept-current-line)))
         (string-match-p "^| +:[^: ]+" line))))

(defun concept-on-attribute-line ()
  "Test if the current line is an attribute line.
An attribute line ends with a colon."
  (let ((line (concept-current-line)))
    (and (string-match-p "^| +" line)
         (string-match-p "[^: ]+: *$" line))))

(defun concept-get-attribute ()
  "Store the attribute group keyword as a string."
  (when (concept-on-attribute-line)
    (let* ((line (concept-current-line))
           (end  (string-match ":" line))
           (start (1+ (string-match "|" line))))
      (string-trim (substring line start end)))))

(defun concept-get-resource-block-attributes ()
  "Get a list of all the attribute names in a resource block."
  (when (concept-on-resource-line)
    (save-excursion
      (end-of-line)
      (let ((boundary
             (save-excursion
               (outline-next-heading)
               (backward-char)
               (point)))
            (attributes nil))
        (while (re-search-forward concept-attribute-group-name-regexp boundary t)
          (push (substring-no-properties (match-string 1)) attributes))
        (delete-dups (nreverse attributes))))))

(defun concept-get-concept-block-relationships ()
  "Get a list of all the relationship names in a concept block."
  (when (concept-on-focus-line)
    (save-excursion
      (end-of-line)
      (let ((boundary
             (save-excursion
               (outline-next-heading)
               (backward-char)
               (point)))
            (relationships nil))
        (while (re-search-forward concept-relationship-name-regexp boundary t)
          (push (substring-no-properties (match-string 1)) relationships))
        (delete-dups (nreverse relationships))))))

(defun concept-get-concept-block-data-concepts ()
  "Get a list of all the data concept names in a concept block."
  (when (concept-on-focus-line)
    (save-excursion
      (end-of-line)
      (let ((boundary
             (save-excursion
               (outline-next-heading)
               (backward-char)
               (point)))
            (concepts nil))
        (while (re-search-forward concept-object-name-regexp boundary t)
          (push (substring-no-properties (match-string 1)) concepts))
        (delete-dups (nreverse concepts))))))

(defun concept-get-relationship ()
  "Get the relationship name of a relationship line."
  (when (concept-on-relationship-line)
    (let* ((line (concept-current-line))
           (start (string-match ":" line)))
      (substring line (1+ start)))))

(defun concept-on-exposition-line ()
  "Test if the current line is an exposition line.
An exposition line is a line in a resource block where expository text
is added to give an illustrated example. Practically, it consists of a
line that starts with open and closing squiggly brackets, usually. It
can also start with square brackets, or maybe unicode quotes: ‘’."
  (let ((line (concept-current-line)))
    (or
     (string-match-p "^|[ ]+{[^}]*} *$" line)
     (string-match-p "| +‘[^‘]*’ *$" line)
     (and
      (string-match-p "^|[ ]*\\[" line)
      (string-match-p "\\][ ]*$" line)))))

(defun concept-insert-note-block ()
  "Insert a note block.
A note block has an open and closing bracket. It is the characteristic
syntax to flesh out details on an exposition line."
  (concept-insert-note-line)
  (concept-add-new-data)
  (insert "{}")
  (backward-char 1))

(defun concept-insert-keyword-block (name)
  "Insert a keyword block with NAME.
A keyword block has an open and closing bracket. It is the characteristic
syntax to flesh out details on an exposition line."
  (concept-insert-keyword-line name)
  (concept-add-new-data)
  (insert "{}")
  (backward-char 1))

(defun concept-toggle-brackets ()
  "Toggle brackets between {} and [].
This has been deprecated in favor of M-r which rotates between three
distinct behaviors."
  (when (concept-on-exposition-line)
    (if (string= "{" (concept--exposition-bracket))
        (concept--squiggle-to-square-bracket)
      (concept--square-to-squiggle-bracket))))

(defun concept-turn-squiggly-into-square-brackets (string)
  (replace-regexp-in-string "{\\([^}]+\\)}" "[\\1]" string))

(defun concept-turn-square-into-squiggly-brackets (string)
  (replace-regexp-in-string "\\[\\([^]]+\\)\\]" "{\\1}" string))

(defun concept--increment-frequency (key table)
  "Increment the occurrence count for KEY in the hash table."
  (let ((current-count (gethash key table 0)))
    (puthash key (1+ current-count) table)))

(defun concept--frequency (key table)
  "Return the occurrence count for KEY in the hash table."
  (gethash key table 0)) ; Return the count, default to 0 if not found

(defun concept-find-all-relationships ()
  "Find all relationship names in a file.

Sort this relationship in order of usage frequency."
  (let ((pattern ":[^:~ ]+$")
        (relationships (make-hash-table :test 'equal)))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward pattern nil t)
        (let* ((line (concept-current-line))
               (start (1+ (string-match ":" line)))
               (end (length line))
               (entry (string-trim (substring line start end))))
          (when (concept-on-relationship-line)
            (concept--increment-frequency entry relationships)))))
    (let (counts '())
      (maphash (lambda (key count)
                 (push (cons key count) counts))
               relationships)
      (mapcar #'car (sort counts (lambda (a b) (> (cdr a) (cdr b))))))))

(defun concept-find-all-attributes ()
  "Find all attribute names in a file.

Sort these attributes in order of usage frequency."
  (let ((pattern "[^ ]+:")
        (attributes (make-hash-table :test 'equal)))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward pattern nil t)
        (let* ((line (concept-current-line))
               (end (string-match ":" line))
               (start 2)
               (bracket (string-match "{" line))
               (entry (string-trim (substring-no-properties line start end))))
          (when (concept-on-attribute-line)
            (concept--increment-frequency entry attributes)))))
    (let (counts '())
      (maphash (lambda (key count)
                 (push (cons key count) counts))
               attributes)
      (mapcar #'car (sort counts (lambda (a b) (> (cdr a) (cdr b))))))))

(defun concept-find-all-resources ()
  "Find all resource names in a file.

Sort these names in order of usage frequency."
  (let ((pattern "^@")
        (resources (make-hash-table :test 'equal)))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward pattern nil t)
        (let* ((line (concept-current-line))
               (end (length line))
               (start (1+ (string-match "@")))
               (entry (substring line start end)))
          (when (concept-on-resource-line)
            (concept--increment-frequency entry resources)))))
    (let (counts '())
      (maphash (lambda (key count)
                 (push (cons key count) counts))
               resources)
      (mapcar #'car (sort counts (lambda (a b) (> (cdr a) (cdr b))))))))

(defun concept-find-all-expositions (attribute)
  "Find all expositions for a specific attribute in a concept file.

Sort these names in order of usage frequency."
  (let ((expositions (make-hash-table :test 'equal)))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward (format "^| *%s:" attribute) nil t)
        (let ((current-data (concept-get-attribute-data))
              (current-attrib (concept-current-attribute)))
          (when (string-equal attribute current-attrib)
            (dolist (entry current-data)
              (concept--increment-frequency entry expositions))))))
    (let (counts '())
      (maphash (lambda (key count)
                 (push (cons key count) counts))
               expositions)
      (mapcar #'car (sort counts (lambda (a b) (> (cdr a) (cdr b))))))))

(defun concept-find-all-concepts ()
  "Find all concept names in a file.
Sort these names in order of usage frequency."
  (let ((pattern concept-subject-or-object-line-regexp)
        (concepts (make-hash-table :test 'equal)))
    (save-excursion
      (concept--goto-first-heading)
      (while (re-search-forward pattern nil t)
        (unless (concept-on-blank-line)
          (let* ((line (concept-current-line))
                 (start 2)
                 (entry (string-trim-left (substring line start))))
            (concept--increment-frequency entry concepts)))))
    (let (counts '())
      (maphash (lambda (key count)
                 (push (cons key count) counts))
               concepts)
      (mapcar #'car (sort counts (lambda (a b) (> (cdr a) (cdr b))))))))

(defun concept-current-attribute ()
  "Get the current attribute and return it as a string."
  (if (concept-on-exposition-line)
      (save-excursion
        (previous-line)
        (concept-current-attribute))
    (and (concept-on-attribute-line)
         (save-excursion
           (beginning-of-line)
           (let* ((line (concept-current-line))
                  (start (string-match "[^| :]" line))
                  (end (string-match ":" line))
                  (entry (string-trim (substring-no-properties line start end))))
             entry)))))

(defun concept-next-attribute ()
  "Get the next attribute and return it as a string."
  (when (and (concept-in-resource-block)
             (not (concept-on-resource-line)))
    (save-excursion
      (concept-goto-next-attribute-boundary)
      (concept-current-attribute))))

(defun concept-current-exposition ()
  "Get the current exposition and return it as a string."
  (when (concept-on-exposition-line)
    (save-excursion
      (beginning-of-line)
      (let* ((line (concept-current-line))
             (start (string-match "{" line))
             (end (string-match "}" line))
             (entry (string-trim (substring-no-properties line (1+ start) end))))
        entry))))

(defun concept-next-exposition ()
  "Get the next exposition and return it as a string."
  (when (concept-on-exposition-line)
    (save-excursion
      (forward-line)
      (when (concept-on-exposition-line)
        (concept-current-exposition)))))

(defun concept-current-concept ()
  "Get the current concept and return as a string."
  (when (concept-on-concept-line)
    (if (concept-on-blank-line)
        ""
      (let* ((line (concept-current-line))
             (end (length line))
             (start 2)
             (entry (string-trim (substring line start end))))
        entry))))

(defun concept-next-data-concept ()
  "Get the next data concept and return it a as a string."
  (save-excursion
    (concept-goto-next-data-concept)
    (concept-current-concept)))

(defun concept-current-focus ()
  "Get the current focus concept as a string."
  (when (concept-in-relationship-block)
    (save-excursion
      (concept-goto-current-focus)
      (concept-current-concept))))

(defun concept-current-relationship ()
  "Get the current relationship and return it as a string."
  (when (and (concept-in-relationship-block)
             (concept-on-data-line))
    (if (concept-on-relationship-line)
        (concept-get-relationship)
      (save-excursion
        (re-search-backward "^| +:")
        (concept-get-relationship)))))

(defun concept-current-resource ()
  "Get the current resource and return as a string."
  (when (concept-on-resource-line)
    (let* ((line (concept-current-line))
           (end (length line))
           (start 2)
           (entry (string-trim (substring-no-properties line start end))))
      entry)))

(defun concept-current-resource-name ()
  "Get the name of the current resource."
  (when (concept-in-resource-block)
    (save-excursion
      (re-search-backward "^@ +" nil t)
      (concept-current-resource))))

(defun concept-change-concept ()
  "Replace the current concept with another one.

Choose the new concept from initially ordered list of all resources."
  (interactive)
  (when (concept-on-concept-line)
    (let* ((choices (concept-find-all-concepts))
           (current (concept-current-concept))
           (vertico-sort-function nil)
           (pick (completing-read
                  "Concept: "
                  (sort
                   choices
                   (lambda (a b)
                     (< (string-distance a current)
                        (string-distance b current))))
                  nil t nil)))
      (when (< 0 (length pick))
        (beginning-of-line)
        (forward-char 1)
        (unless (or (equal (point) (line-end-position))
                    (equal (point) (- (line-end-position) 1)))
          (kill-line))
        (insert " ")
        (insert pick)
        (when (looking-at "~")
          (insert "\n"))
        (delete-horizontal-space)))))

(defun concept-change-exposition ()
  "Replace the current exposition data with another having the same attribute elsewhere in the file"
  (interactive)
  (when (concept-on-exposition-line)
    (let* ((attrib (concept-current-attribute))
           (choices (concept-find-all-expositions attrib))
           (current (concept-current-exposition))
           (vertico-sort-function nil)
           (pick (completing-read
                  "Exposition: "
                  (sort
                   choices
                   (lambda (a b)
                     (< (string-distance a current)
                        (string-distance b current))))
                  nil t nil)))
      (when (< 0 (length pick))
        (beginning-of-line)
        (forward-char 1)
        (unless (or (equal (point) (line-end-position))
                    (equal (point) (- (line-end-position) 1)))
          (kill-line))
        (insert " {")
        (insert pick)
        (insert "}")))))

(defun concept-slurp-next-concept ()
  "Convert the next focus concept into a data concept for the current focus."
  (interactive)
  (when (concept-on-data-line)
    (let ((is-blank (concept-on-blank-line))
          (line-move-visual nil))
      (cond ((save-excursion
               (next-line)
               (concept-on-focus-line))
             (when is-blank
               (beginning-of-line)
               (kill-line)
               (kill-line)
               (concept-toggle-focus-data)
               (end-of-line))
             (when (not is-blank)
               (next-line)
               (concept-toggle-focus-data)
               (end-of-line)))
            ((save-excursion
               (next-line)
               (concept-on-data-line))
             (when is-blank
               (beginning-of-line)
               (forward-char 2)
               (kill-line)
               (kill-forward-chars 2)))))))

(defun concept-barf-current-concept ()
  "Convert the current data concept into a new focus concept."
  (interactive)
  (let ((on-data-line (concept-on-data-line))
        (on-focus-line (concept-on-focus-line))
        (on-blank-line (concept-on-blank-line))
        (line-move-visual nil))
    (when on-focus-line
      (concept-toggle-focus-data)
      (end-of-line))
    (when (and on-data-line (not on-blank-line))
      (beginning-of-line)
      (kill-line)
      (kill-line)
      (re-search-forward "^~" nil t)
      (beginning-of-line)
      (open-line 1)
      (yank 2)
      (concept-toggle-focus-data)
      (end-of-line))))

(defun concept-change-resource ()
  "Replace the current resource with another one.

Choose the new resource from initially ordered list of all resources."
  (interactive)
  (when (concept-on-resource-line)
    (let* ((choices (concept-find-all-resources))
           (current (concept-current-resource))
           (vertico-sort-function nil)
           (pick (completing-read
                  "Resource: "
                  (sort
                   choices
                   (lambda (a b)
                     (< (string-distance a current)
                        (string-distance b current))))
                  nil t nil)))
      (when (< 0 (length pick))
        (beginning-of-line)
        (re-search-forward "[^@ ]" nil t)
        (backward-char 1)
        (kill-line)
        (insert pick)))))

(defun concept-change-relationship ()
  "Replace the current relationship with another one.

Choose the new relationship from initially ordered list of all relationships."
  (interactive)
  (when (concept-on-relationship-line)
    (let* ((choices (concept-find-all-relationships))
           (vertico-sort-function nil)
           (pick (completing-read
                  "Relationship: "
                  choices
                  nil t nil)))
      (when (< 0 (length pick))
        (beginning-of-line)
        (re-search-forward ":" nil t)
        (kill-line)
        (insert pick)))))

(defun concept-change-attribute ()
  "Replace the current attribute with another one.

Choose the new attribute from initially ordered list of all attributes."
  (interactive)
  (when (concept-on-attribute-line)
    (let* ((choices (concept-find-all-attributes))
           (vertico-sort-function nil)
           (pick (completing-read
                  "Attribute: "
                  choices
                  nil t nil)))
      (when (< 0 (length pick))
        (beginning-of-line)
        (kill-line)
        (insert "| ")
        (insert pick)
        (insert ":")))))

(defun concept-change-concept-or-resource ()
  "Replace the current concept or resource with another one.

This is a wrapper convenience function."
  (interactive)
  (when (concept-on-concept-line)
    (concept-change-concept))
  (when (concept-on-resource-line)
    (concept-change-resource)))

(defun concept-change-attribute-or-relationship ()
  "Replace the current attribute or relationship with another one.

This is a wrapper function useful for interactive usage."
  (interactive)
  (when (concept-on-attribute-line)
    (concept-change-attribute))
  (when (concept-on-relationship-line)
    (concept-change-relationship)))

(defun concept-change-dwim ()
  "Change the thing at point."
  (interactive)
  (concept-change-attribute-or-relationship)
  (concept-change-concept-or-resource)
  (concept-change-exposition))

(defun concept-goto-current-focus ()
  "Navigate back to the current focus line."
  (interactive)
  (unless (concept-on-focus-line)
    (ignore-errors
      (outline-up-heading 1)))
  (end-of-line))

(defun concept-goto-next-blank-line ()
  "Search for the next blank line."
  (re-search-forward "^[[:blank:]]*$" nil t))

(defun concept-goto-next-focus ()
  "Navigate back to the next focus line."
  (interactive)
  (concept-goto-current-focus)
  (condition-case err
      (outline-forward-same-level 1)
    (error (concept-goto-next-blank-line)))
  (end-of-line))

(defun concept-goto-current-resource ()
  "Navigate back to the current resource line."
  (interactive)
  (when (concept-in-resource-block)
    (unless (concept-on-resource-line)
      (ignore-errors
        (outline-up-heading 0)))
    (end-of-line)))

(defun concept-goto-next-concept ()
  "Navigate forward until the next concept"
  (interactive)
  (let ((pattern "^[~|]")
        (line-move-visual nil))
    (next-line)
    (beginning-of-line)
    (while (not (concept-on-concept-line))
      (re-search-forward pattern nil t))
    (end-of-line)))

(defun concept-goto-next-data-concept ()
  "Navigate forward until the next concept"
  (interactive)
  (let ((pattern "^|")
        (line-move-visual nil))
    (next-line)
    (beginning-of-line)
    (while (not (and (concept-on-concept-line)
                     (concept-on-data-line)))
      (re-search-forward pattern nil t))
    (end-of-line)))

(defun concept-goto-last-concept ()
  "Navigate backwards until the last concept"
  (interactive)
  (let ((pattern "^[~|]")
        (line-move-visual nil))
    (previous-line)
    (end-of-line)
    (while (not (concept-on-concept-line))
      (re-search-backward pattern nil t))
    (end-of-line)))

(defun concept-goto-next-relationship ()
  "Navigate forward until the next relationship."
  (interactive)
  (let ((line-move-visual nil))
    (if (re-search-forward concept-next-relationship-group-line-regexp nil t)
        (progn (beginning-of-line) (backward-char))
      (goto-char (point-max)))))

(defun concept-narrow-to-concept-block ()
  (interactive)
  (save-excursion
    (ignore-errors
      (outline-up-heading 1))
    (let ((start (point)))
      (outline-end-of-subtree)
      (narrow-to-region start (point)))))

(defun concept-narrow-to-resource-block ()
  (interactive)
  (when (concept-in-resource-block)
    (save-excursion
      (end-of-line)
      (outline-previous-heading)
      (let ((start (point)))
        (outline-end-of-subtree)
        (narrow-to-region start (point))))))

(defun concept-goto-last-relationship ()
  "Navigate backward until the last relationship"
  (interactive)
  (let ((pattern concept-next-relationship-group-line-regexp)
        (line-move-visual nil))
    (previous-line)
    (beginning-of-line)
    (while (and (not (bobp))
                (not (concept-on-relationship-line)))
      (previous-line))
    (end-of-line)))

(defun concept-goto-next-resource ()
  "Navigate forward until the next resource line"
  (interactive)
  (end-of-line)
  (or (re-search-forward concept-resource-line-regexp nil t)
      (goto-char (point-max)))
  (end-of-line))

(defun concept-goto-previous-resource ()
  "Navigate forward until the next resource line"
  (interactive)
  (beginning-of-line)
  (or (re-search-backward concept-resource-line-regexp nil t)
      (goto-char (point-min)))
  (end-of-line))

(defun concept-goto-next-resource-line-with-any-of (parts)
  (let ((re (concat "^@ +" (concept--form-partial-match parts))))
    (end-of-line)
    (or
     (prog1
       (re-search-forward re nil t)
       (previous-line)
       (end-of-line))
     (goto-char (point-max)))))

(defun concept-goto-next-concept-block ()
  "Navigate forward until the next concept focus line"
  (interactive)
  (when (not (concept-on-focus-line))
    (ignore-errors
      (outline-up-heading 1)))
  (when (concept-map-has-more-concept-blocks)
    (outline-forward-same-level 1)))

(defun concept-goto-next-concept-block-or-stay ()
  "Navigate forward until the next concept focus line as long as you aren't on one."
  (interactive)
  (when (not (concept-on-focus-line))
    (concept-goto-next-concept-block)))

(defun concept-goto-previous-concept-block-or-stay ()
  "Navigate forward until the next concept focus line as long as you aren't on one."
  (interactive)
  (when (not (concept-on-focus-line))
    (concept-goto-previous-concept-block)))

(defun concept-goto-last-resource-or-stay ()
  "Navigate backward to last resource line as long as you aren't on one."
  (interactive)
  (when (not (concept-on-resource-line))
    (concept-goto-last-resource)))

(defun concept-goto-next-attribute ()
  "Navigate forward until the next resource line"
  (interactive)
  (let ((pt (point)))
    (next-line)
    (beginning-of-line)
    (catch 'done
      (while (not (concept-on-attribute-line))
        (when (concept-on-last-line-p)
          (goto-char pt)
          (message "No more attributes in visible buffer!")
          (throw 'done nil))
        (next-line))
      (end-of-line)
      t)))

(defun concept-goto-next-exposition ()
  "Navigate forward until the next resource line"
  (interactive)
  (next-line)
  (beginning-of-line)
  (while (not (concept-on-exposition-line))
    (next-line))
  (end-of-line))

(defun concept-goto-next-thing ()
  "Navigate forward until the next thing like the current thing."
  (interactive)
  (cond ((concept-on-resource-line)
         (concept-goto-next-resource))
        ((concept-on-concept-line)
         (concept-goto-next-concept))
        ((concept-on-relationship-line)
         (concept-goto-next-relationship))
        ((concept-on-attribute-line)
         (concept-goto-next-attribute))
        ((concept-on-exposition-line)
         (concept-goto-next-exposition))))

(defun concept-on-data-concept-line ()
  "Test if the current line is a data concept line."
  (and (concept-on-concept-line)
       (concept-on-data-line)))

(defun concept-goto-last-resource ()
  "Navigate backward until the last resource line"
  (interactive)
  (let ((line-move-visual nil))
    (previous-line)
    (end-of-line)
    (while (not (concept-on-resource-line))
      (previous-line))
    (end-of-line)))

(defun concept--exchange-concept (direction &optional times)
  "Toggle the lines a la C-x C-t.

When on a concept line that is not the focus, exchange the concept line
with either the next line or the previous line as long as those are also
concepts."
  (when (null times)
    (setq times 1))
  (let ((line-move-visual nil))
    (when (concept-on-concept-line)
      (when (< times 0)
        (user-error "TIMES must be positive."))
      (dotimes (i times)
        (when (save-excursion
                (if (equal direction "up")
                    (previous-line)
                  (next-line))
                (and (concept-on-data-line)
                     (concept-on-concept-line)))
          (if (equal direction "up")
              (progn
                (transpose-lines 1)
                (previous-line 2))
            (progn
              (next-line)
              (transpose-lines 1)
              (previous-line))))
        (end-of-line)))))

(defun concept-exchange-concept-up (&optional times)
  "Exchange concept with the previous one."
  (interactive)
  (concept--exchange-concept "up" times))

(defun concept-exchange-concept-down (&optional times)
  "Exchange concept with the next one."
  (interactive)
  (concept--exchange-concept "down" times))

(defun concept--exchange-exposition (direction &optional times)
  "Toggle the lines a la C-x C-t.

When on an exposition line, exchange it with either the next or previous
adjacent exposition line."
  (when (concept-on-exposition-line)
    (when (null times)
      (setq times 1))
    (when (< times 0)
      (user-error "TIMES must be positive."))
    (dotimes (_ times)
      (let ((line-move-visual nil))
        (when (concept-on-exposition-line)
          (when (save-excursion
                  (if (equal direction "up")
                      (previous-line)
                    (next-line))
                  (concept-on-exposition-line))
            (if (equal direction "up")
                (progn
                  (transpose-lines 1)
                  (previous-line 2))
              (progn
                (next-line)
                (transpose-lines 1)
                (previous-line)))))))))

(defun concept-exchange-exposition-up (&optional times)
  "Exchange exposition with the previous one."
  (interactive)
  (concept--exchange-exposition "up" times))

(defun concept-exchange-exposition-down (&optional times)
  "Exchange exposition with the next one."
  (interactive)
  (concept--exchange-exposition "down" times))

(defun concept-goto-next-attribute-boundary ()
  "Move to the next keyword, concept header, or block marker."
  (interactive)
  (end-of-line)
  (when (re-search-forward
       (concat concept-attribute-group-line-regexp
               "\\|"
               concept-subject-line-regexp
               "\\|"
               concept-resource-line-regexp
               "\\|"
               "^[ \t]*$")
       nil t)
    (beginning-of-line)
    (point)))

(defun concept-goto-next-relationship-boundary ()
  "Move to the next relationship boundary.
This could be another relationship group, a new idea which starts with a
focus concept creating a new relationship block, or a new resource
block."
  (interactive)
  (end-of-line)
  (when (re-search-forward
       (concat concept-relationship-group-line-regexp
               "\\|"
               concept-subject-line-regexp
               "\\|"
               concept-resource-line-regexp
               "\\|"
               "^[ \t]*$")
       nil t)
    (beginning-of-line)
    (point)))

(defun concept-goto-previous-attribute-boundary ()
  "Move to the next keyword, concept header, or block marker."
  (interactive)
  (beginning-of-line)
  (when (re-search-backward
         (concat concept-attribute-group-line-regexp
                 "\\|"
                 concept-subject-line-regexp
                 "\\|"
                 concept-resource-line-regexp
                 "\\|"
                 "^[ \t]*$")
         nil t)
    (beginning-of-line)
    (point)))

(defun concept-goto-previous-relationship-boundary ()
  "Move to the previous relationship, concept header, or resource block marker."
  (interactive)
  (beginning-of-line)
  (when (re-search-backward
         (concat concept-relationship-group-line-regexp
                 "\\|"
                 concept-subject-line-regexp
                 "\\|"
                 concept-resource-line-regexp
                 "\\|"
                 "^[ \t]*$")
         nil t)
    (beginning-of-line)
    (point)))

(defun concept-move-attribute-down (&optional times)
  "Move the keyword and its data below the next keyword and its data."
  (interactive)
  (when (null times)
    (setq times 1))
  (when (< times 0)
    (user-error "TIMES must be positive."))
  (dotimes (_ times)
    (let (current-start
          current-end
          current-keyword
          next-start
          next-end
          current-text
          next-text)
      (save-excursion
        (beginning-of-line)
        (unless (looking-at concept-attribute-group-line-regexp)
          (user-error "Point is not on a keyword line"))
        (setq current-keyword (concept-get-attribute))
        (setq current-start (point))
        (forward-line 1)
        (setq current-end (concept-goto-next-attribute-boundary))
        (unless current-end
          (user-error "Current keyword has no following keyword"))
        (goto-char current-end)
        (unless (looking-at concept-attribute-group-line-regexp)
          (user-error "No following keyword in this block"))
        (setq next-start (point))
        (forward-line 1)
        (setq next-end (concept-goto-next-attribute-boundary))
        (unless next-end
          (setq next-end (point-max)))
        (setq current-text
              (buffer-substring-no-properties current-start current-end)
              next-text
              (buffer-substring-no-properties next-start next-end)))
      (atomic-change-group
        (goto-char current-start)
        (delete-region current-start next-end)
        (insert next-text current-text))
      (goto-char current-start)
      (re-search-forward (concat current-keyword ":")))))

(defun concept-move-attribute-up (&optional times)
  "Move the keyword and its data above the previous keyword and its data."
  (interactive)
  (when (null times)
    (setq times 1))
  (when (< times 0)
    (user-error "TIMES must be positive."))
  (dotimes (_ times)
    (let (current-start
          current-end
          current-keyword
          previous-start
          current-text
          previous-text)
      (save-excursion
        (beginning-of-line)
        (unless (looking-at concept-attribute-group-line-regexp)
          (user-error "Point is not on a resource keyword line"))
        (setq current-keyword (concept-get-attribute))
        (setq current-start (point))
        (setq previous-start
              (concept-goto-previous-attribute-boundary))
        (unless previous-start
          (user-error "Current keyword has no preceding keyword"))
        (unless (looking-at concept-attribute-group-line-regexp)
          (user-error "No preceding keyword in this block"))
        (goto-char current-start)
        (forward-line 1)
        (setq current-end
              (or (concept-goto-next-attribute-boundary)
                  (point-max)))
        (setq previous-text
              (buffer-substring-no-properties
               previous-start current-start)
              current-text
              (buffer-substring-no-properties
               current-start current-end)))
      (atomic-change-group
        (goto-char previous-start)
        (delete-region previous-start current-end)
        (insert current-text previous-text))
      (re-search-backward (concat current-keyword ":"))
      (end-of-line))))

(defun concept-move-relationship-group-up (&optional times)
  "Move the relationship-group and its data above the previous relationship-group and its data."
  (interactive)
  (when (null times)
    (setq times 1))
  (when (< times 0)
    (user-error "TIMES must be positive."))
  (dotimes (i times)
    (let (current-start
          current-end
          current-relationship-group
          previous-start
          current-text
          previous-text)
      (save-excursion
        (beginning-of-line)
        (unless (looking-at concept-relationship-group-line-regexp)
          (user-error "Point is not on a resource relationship-group line"))
        (setq current-relationship-group (concept-get-relationship))
        (setq current-start (point))
        (setq previous-start
              (concept-goto-previous-relationship-boundary))
        (unless previous-start
          (user-error "Current relationship-group has no preceding relationship-group"))
        (unless (looking-at concept-relationship-group-line-regexp)
          (user-error "No preceding relationship-group in this block"))
        (goto-char current-start)
        (forward-line 1)
        (setq current-end
              (or (concept-goto-next-relationship-boundary)
                  (point-max)))
        (setq previous-text
              (buffer-substring-no-properties
               previous-start current-start)
              current-text
              (buffer-substring-no-properties
               current-start current-end)))
      (atomic-change-group
        (goto-char previous-start)
        (delete-region previous-start current-end)
        (insert current-text previous-text))
      (re-search-backward (concat ":" current-relationship-group))
      (end-of-line))))

(defun concept-move-relationship-group-down (&optional times)
  "Move the relationship-group and its data below the next relationship-group and its data."
  (interactive)
  (when (null times)
    (setq times 1))
  (when (< times 0)
    (user-error "TIMES must be positive."))
  (dotimes (i times)
    (let (current-start
          current-end
          current-relationship-group
          next-start
          next-end
          current-text
          next-text)
      (save-excursion
        (beginning-of-line)
        (unless (looking-at concept-relationship-group-line-regexp)
          (user-error "Point is not on a relationship-group line"))
        (setq current-relationship-group (concept-get-relationship))
        (setq current-start (point))
        (forward-line 1)
        (setq current-end (concept-goto-next-relationship-boundary))
        (unless current-end
          (user-error "Current relationship-group has no following relationship-group"))
        (goto-char current-end)
        (unless (looking-at concept-relationship-group-line-regexp)
          (user-error "No following relationship-group in this block"))
        (setq next-start (point))
        (forward-line 1)
        (setq next-end (concept-goto-next-relationship-boundary))
        (unless next-end
          (setq next-end (point-max)))
        (setq current-text
              (buffer-substring-no-properties current-start current-end)
              next-text
              (buffer-substring-no-properties next-start next-end)))
      (atomic-change-group
        (goto-char current-start)
        (delete-region current-start next-end)
        (insert next-text current-text))
      (goto-char current-start)
      (re-search-forward (concat ":" current-relationship-group)))))

(defun concept-exchange-down-dwim ()
  "Exchange the current thing with the following thing."
  (interactive)
  (when (and (concept-on-data-line)
             (concept-on-concept-line))
    (concept-exchange-concept-down))
  (when (concept-on-attribute-line)
    (concept-move-attribute-down))
  (when (concept-on-exposition-line)
    (concept-exchange-exposition-down))
  (when (concept-on-relationship-line)
    (concept-move-relationship-group-down))
  (when (concept-on-resource-line)
    (outline-move-subtree-down 1))
  (when (concept-on-focus-line)
    (outline-move-subtree-down 1)))

(defun concept-exchange-up-dwim ()
  "Exchange the current thing with the following thing."
  (interactive)
  (when (and (concept-on-data-line)
             (concept-on-concept-line))
    (concept-exchange-concept-up))
  (when (concept-on-attribute-line)
    (concept-move-attribute-up))
  (when (concept-on-exposition-line)
    (concept-exchange-exposition-up))
  (when (concept-on-relationship-line)
    (concept-move-relationship-group-up))
  (when (concept-on-resource-line)
    (outline-move-subtree-up 1))
  (when (concept-on-focus-line)
    (outline-move-subtree-up 1)))

(defun concept-goto-last-exposition ()
  "Navigate backward until the last exposition line"
  (interactive)
  (let ((line-move-visual nil))
    (beginning-of-line)
    (previous-line)
    (while (not (concept-on-exposition-line))
      (previous-line))
    (end-of-line)))

(defun concept-goto-last-attribute ()
  "Navigate backward until the last exposition line"
  (interactive)
  (let ((line-move-visual nil))
    (previous-line)
    (beginning-of-line)
    (while (not (concept-on-attribute-line))
      (previous-line))
    (end-of-line)))

(defun concept-go-one-group-up ()
  "Navigate backwards to the last group."
  (interactive)
  (cond ((or (concept-on-resource-line)
             (concept-on-focus-line)
             (and (concept-on-attribute-line)
                  (save-excursion
                    (previous-line)
                    (concept-on-resource-line)))
             (and (concept-on-relationship-line)
                  (save-excursion
                    (previous-line)
                    (concept-on-focus-line))))
         (outline-previous-visible-heading 1)
         (end-of-line))
        ((or (concept-on-data-concept-line)
             (concept-on-relationship-line))
         (concept-goto-last-relationship))
        ((or (concept-on-attribute-line)
             (concept-on-exposition-line))
         (concept-goto-last-attribute))))

(defun concept-current-delimiter ()
  (when (concept-on-exposition-line)
    (save-excursion
      (beginning-of-line)
      (re-search-forward "[^| ]")
      (backward-char)
      (let ((pt (point)))
        (buffer-substring-no-properties pt (1+ pt))))))

(defun concept-go-one-group-down ()
  "Navigate forwards to the next group."
  (interactive)
  (cond ((concept-on-focus-line)
         (concept-goto-next-relationship))
        ((concept-on-resource-line)
         (concept-goto-next-attribute))
        ((concept-on-relationship-line)
         (concept-goto-next-data-concept))
        ((concept-on-data-concept-line)
         (concept-goto-next-relationship-boundary)
         (end-of-line))
        ((concept-on-attribute-line)
         (concept-goto-next-exposition)
         (beginning-of-line)
         (re-search-forward (concept-current-delimiter) (line-end-position) t))
        ((concept-on-exposition-line)
         (concept-goto-next-attribute-boundary)
         (end-of-line))))

(defun concept-goto-last-thing ()
  "Navigate backward until the previous thing like the current thing."
  (interactive)
  (cond ((concept-on-resource-line)
         (concept-goto-last-resource))
        ((concept-on-concept-line)
         (concept-goto-last-concept))
        ((concept-on-relationship-line)
         (concept-goto-last-relationship))
        ((concept-on-attribute-line)
         (concept-goto-last-attribute))
        ((concept-on-exposition-line)
         (concept-goto-last-exposition))))

(defun concept-relationship-count ()
  "Count the number of relationships inside of a relationship block.
This starts at the focus line and increments every time a data line is found.
"
  (interactive)
  (let ((line-move-visual nil))
    (save-excursion
      (concept-goto-current-focus)
      (next-line)
      (let ((n 0))
        (while (and (concept-in-relationship-block)
                    (not (concept-on-focus-line)))
          (when (and (concept-on-data-line)
                     (not (concept-on-relationship-line)))
            (setq n (1+ n)))
          (next-line))
        n))))

(defun concept-relationship-group-count ()
  "Count the number of relationship groups inside of a relationship block.
This starts at the focus line and increments every time a new
relationship line is found."
  (let ((line-move-visual nil))
    (save-excursion
      (concept-goto-current-focus)
      (next-line)
      (let ((n 0))
        (while (and (concept-in-relationship-block)
                    (not (concept-on-focus-line)))
          (when (concept-on-relationship-line)
            (setq n (1+ n)))
          (next-line))
        n))))

(defun concept-relationship-group-concept-count ()
  "Count the number of data concepts."
  (when (and (concept-in-relationship-block)
             (not (concept-on-focus-line)))
    (save-excursion
      (when (concept-on-data-concept-line)
        (concept-goto-last-relationship))
      (let ((pt0 (point)))
        (concept-goto-next-relationship-boundary)
        (let ((pt1 (point)))
          (- (line-number-at-pos pt1)
             (line-number-at-pos pt0)
             1))))))

(defun concept-in-last-relationship-in-block-p ()
  "Test if the curent relationship is the last relationship in the block."
  (when (and (concept-in-relationship-block)
             (concept-on-data-line))
    (save-excursion
      (concept-goto-next-relationship-boundary)
      (or (concept-on-resource-line)
          (concept-on-focus-line)))))

(defun concept-in-last-attribute-in-block-p ()
  "Test if the curent attribute is the last attribute in the block."
  (when (and (concept-in-resource-block)
             (concept-on-data-line))
    (save-excursion
      (concept-goto-next-attribute-boundary)
      (or (concept-on-resource-line)
          (concept-on-focus-line)))))

(defun concept-goto-first-relationship-group-in-block ()
  "Navigate back to the first relationship group in the current relationship block."
  (concept-goto-current-focus)
  (forward-line)
  (end-of-line))

(defun concept-goto-first-attribute-group-in-block ()
  "Navigate back to the first attribute group in the current resource block."
  (when (concept-in-resource-block)
    (concept-goto-current-resource)
    (forward-line)
    (end-of-line)))

(defun concept-goto-first-resource-block-in-idea ()
  "Navigate back to the first resource block in the current idea."
  (when (< 0 (concept-resource-block-count))
    (concept-goto-current-focus)
    (concept-goto-next-resource)
    (end-of-line)))

(defun concept-on-first-resource-line-in-idea ()
  "Test whether this is the first resource line in the current idea."
  (and (concept-on-resource-line)
       (save-excursion
         (end-of-line)
         (let ((pt0 (point)))
           (concept-goto-current-focus)
           (concept-goto-next-resource)
           (end-of-line)
           (let ((pt1 (point)))
             (eq pt0 pt1))))))

(defun concept-goto-first-exposition-line-in-attribute-group ()
  "Navigate back to the first exposition line in the current attribute group."
  (cond ((concept-on-exposition-line)
         (concept-goto-previous-attribute-boundary)
         (end-of-line)
         (forward-line))
        ((concept-on-attribute-line)
         (end-of-line)
         (forward-line))))

(defun concept-relationship-group-partial-sort (&optional max-iter)
  "Sort the relationship groups in alphabetical order."
  (interactive "P")
  (when (and (concept-in-relationship-block)
             (or (< 1 (concept-relationship-group-count))
                 (end-of-line)))
    (when (null max-iter)
      (setq max-iter concept-map-bubble-sort-maximum-iterations))
    (concept-goto-first-relationship-group-in-block)
    (let ((line (line-number-at-pos (point))))
      (catch 'done
        (let ((i 0)
              (swapped nil))
          (while (< i max-iter)
            (let ((a (concept-current-relationship))
                  (length-a (concept-relationship-group-length))
	          (b (concept-next-relationship))
                  (length-b (concept-next-relationship-group-length)))
              (cond
               ((concept-in-last-relationship-in-block-p)
                (when (null swapped)
                  (throw 'done 'sorted))
                (setq swapped nil)
                (concept-goto-first-relationship-group-in-block))
               ((concept-string-lessp-with-length-tie-break a b length-a length-b)
	        (concept-goto-next-relationship))
               (t
                (setq swapped t)
	        (concept-move-relationship-group-down))))
            (setq i (1+ i)))))
      (goto-line line)
      (end-of-line))))

(defun concept-attribute-group-partial-sort (&optional max-iter)
  "Sort the attribute groups in alphabetical order."
  (interactive "P")
  (when (and (concept-in-resource-block)
             (or (< 1 (concept-resource-keyword-count))
                 (end-of-line)))
    (when (null max-iter)
      (setq max-iter concept-map-bubble-sort-maximum-iterations))
    (concept-goto-first-attribute-group-in-block)
    (let ((line (line-number-at-pos (point))))
      (catch 'done
        (let ((i 0)
              (swapped nil))
          (while (< i max-iter)
            (let ((a (concept-current-attribute))
                  (length-a (concept-attribute-group-length))
	          (b (concept-next-attribute))
                  (length-b (concept-next-attribute-group-length)))
              (cond
               ((concept-in-last-attribute-in-block-p)
                (when (null swapped)
                  (throw 'done 'sorted))
                (setq swapped nil)
                (concept-goto-first-attribute-group-in-block))
               ((concept-string-lessp-with-length-tie-break a b length-a length-b)
	        (concept-goto-next-attribute))
               (t
                (setq swapped t)
	        (concept-move-attribute-down))))
            (setq i (1+ i)))))
      (goto-line line)
      (end-of-line))))

(defun concept-alphabetic-sort-dwim (arg)
  "Perform a partial sort of the thing at point."
  (interactive "P")
  (if (null arg)
      (cond ((concept-on-data-concept-line)
             (concept-data-concept-partial-sort))
            ((concept-on-attribute-line)
             (concept-attribute-group-partial-sort))
            ((concept-on-relationship-line)
             (concept-relationship-group-partial-sort))
            ((concept-on-resource-line)
             (concept-resource-partial-sort))
            ((concept-on-exposition-line)
             (concept-exposition-partial-sort))
            ((concept-on-focus-line)
             (concept-idea-partial-sort)))
    (concept--goto-first-heading)
    (while (not (or (eobp) (concept-on-last-line-p)))
      (when (or (concept-on-first-concept)
                (concept-on-first-relationship-line)
                (concept-on-first-data-concept-line)
                (concept-on-first-resource-line-in-idea)
                (concept-on-first-attribute-line)
                (concept-on-exposition-line))
        (save-excursion
          (concept-alphabetic-sort-dwim nil)))
      (concept-go-one-group-down)
      (when (and (concept-current-line-blank-p)
                 (not (concept-on-last-line-p)))
        (user-error "Landed on a blank line in the middle of sorting the file. Aborting!")))
    (concept--goto-first-heading)))

(defvar concept-canonical-custom-sort-dwim-function nil
  "An custom sort function similar to `concept-alphabetic-sort-dwim'
which provides sorting functionality at least for the levels of sorting
you are interested in.")

(defvar concept-canonical-sort-string
  "AAAAAA"
  "Six capital letter string setting the sorting order.
The different letters mean:

A) for alphabetical sort with length tie break (i.e., `concept-alphabetical-sort-dwim')
B) for alphabetical sort except for a few patterns which when matched come first in specified order
E) for alphabetical sort except for a few patterns which when matched come last in specified order
Z) for reverse alphabetical sort with length tie break (i.e., reversing `concept-alphabetical-sort-dwim')
Y) for reverse alphabetical sort except for a few patterns which come last in a specified order
X) for reverse alphabetical sort except for a few patterns which come first in a specified order
J) for no sort leaving them just so (i.e., doing nothing)
C) for a custom sort corresponding to `concept-canonical-custom-sort-dwim-function'
S) for sorting purely based on string length short to long (TODO)
L) for sorting purely based on string length long to short (TODO)

There are six because there are 3 for the three levels of elements in relationship blocks:

1. focus concepts (subjects)
2. relationship groups
3. data concepts (objects)

Similarly, there are 3 more levels for resource blocks.

4. resource blocks
5. attribute group keywords
6. exposition lines

Note that sticking to just alphabetical can be fine as long as the diff
is done after a git filter and not on the existing buffer. However, when
you want to keep the buffer itself more organized, that's when these
other piece of functionality become appealing.")

(defun concept-canonical-sort-string-is-valid-p (string)
  "Test whether the value  of the variable `concept-canonical-sort-string' is valid."
  (and (eq 6 (length string))
       (string-match-p "^[ABCEXYZLSJ]+$")))

(defun concept-canonical-sort-dwim (arg)
  "Perform a canonical sort of the whole concept map.
The user has significant control over what a canonical sort is. This
control is exercised through modifying the global variables:
`concept-canonical-sort-string'."
  (interactive "P")
  (unless (concept-canonical-sort-string-is-valid-p
           concept-canonical-sort-string)
    (user-error "Invalid within-group canonical sort string!"))
  (unless (concept-canonical-between-group-sort-string-is-valid-p
           concept-canonical-between-group-sort-string)
    (user-error "Invalid between-group canonical sort string!"))
  (if (null arg)
      (cond ((concept-on-data-concept-line)
             (concept-data-canoncial-sort))
            ((concept-on-attribute-line)
             (concept-attribute-group-canonical-sort))
            ((concept-on-relationship-line)
             (concept-relationship-group-canonical-sort))
            ((concept-on-resource-line)
             (concept-resource-canonical-sort))
            ((concept-on-focus-line)
             (concept-canonical-sort)))
    (concept--goto-first-heading)
    (concept-canonical-sort-dwim)
    (while (not (or (eobp)
                    (concept-on-last-line-p)))
      (when (and (not (concept-on-focus-line))
                 (or (concept-on-first-relationship-line)
                     (concept-on-first-attribute-line)
                     (concept-on-exposition-line)))
        (concept-canonical-sort-dwim))
      (concept-go-one-group-down)
      (when (and (concept-current-line-blank-p)
                 (not (concept-on-last-line-p)))
        (user-error "Landed on a blank line in the middle of randomizing the file. Aborting!")))))

(defun concept-resource-block-length ()
  "Count the number of lines inside of the resource block."
  (interactive)
  (when (concept-in-resource-block)
  (let ((line-move-visual nil))
    (save-excursion
      (concept-goto-last-resource-or-stay)
      (next-line)
      (let ((n 0))
        (while (and (not (concept-on-focus-line))
                    (concept-in-resource-block)
                    (not (concept-on-resource-line))
                    (not (eobp)))
          (when (not (concept-on-attribute-line))
            (setq n (1+ n)))
          (next-line))
        n)))))

(defun concept-resource-block-count ()
  "Count the number of resource blocks inside of an idea.
This starts at the focus line and increments every time a new
resource line is found."
  (interactive)
  (let ((line-move-visual nil))
    (save-excursion
      (concept-goto-current-focus)
      (next-line)
      (let ((n 0))
        (while (and (not (concept-on-focus-line))
                    (not (eobp)))
          (when (concept-on-resource-line)
            (setq n (1+ n)))
          (next-line))
        n))))

(defun concept-idea-has-resources ()
  "Test whether the current idea has atleast one resource."
  (< 0 (concept-resource-block-count)))

(defun concept-idea-has-more-resources ()
  "Test whether there are more resources between point and the next idea."
  (let ((pos (point))
        (end
         (save-excursion
           (concept-goto-current-focus)
           (outline-end-of-subtree)
           (point))))
    (save-excursion
      (end-of-line)
      (re-search-forward "^@ +" end t))))

(defun concept-relationship-block-attribute-count ()
  "Count the number of relationship keywords inside of a relationship block.
This starts at the focus line and increments every time a new relationship keyword
line is found."
  (interactive)
  (let ((line-move-visual nil))
    (save-excursion
      (concept-goto-current-focus)
      (next-line)
      (let ((n 0))
        (while (and (not (concept-on-focus-line))
                    (not (eobp)))
          (when (concept-on-attribute-line)
            (setq n (1+ n)))
          (next-line))
        n))))

(defun concept-unique-relationship-block-attribute-count ()
  "Count the number of unique attribute group keywords inside of a resource block.
This starts at the focus line and increments every time a unique
relationship is found."
  (interactive)
  (let ((line-move-visual nil))
    (save-excursion
      (concept-goto-current-focus)
      (next-line)
      (let ((seen (make-hash-table :test #'equal))
            relationship)
        (while (not (concept-on-focus-line))
          (when (concept-on-attribute-line)
            (setq attribute (concept-get-attribute))
            (unless (gethash attribute seen)
              (puthash attribute t seen)))
          (next-line))
        (hash-table-count seen)))))

(defun concept-unique-relationship-group-count ()
  "Count the number of unique relationship groups inside of a relationship block.
This starts at the focus line and increments every time a unique
relationship is found."
  (interactive)
  (let ((line-move-visual nil))
    (save-excursion
      (concept-goto-current-focus)
      (next-line)
      (let ((seen (make-hash-table :test #'equal))
            relationship)
        (while (and (concept-in-relationship-block)
                    (not (concept-on-focus-line)))
          (when (concept-on-relationship-line)
            (setq relationship (concept-get-relationship))
            (unless (gethash relationship seen)
              (puthash relationship t seen)))
          (next-line))
        (hash-table-count seen)))))

(defun concept-unique-resource-block-count ()
  "Count the number of unique resource block names for an idea.
This starts at the focus line and increments every time a unique
resource is found."
  (interactive)
  (let ((line-move-visual nil))
    (save-excursion
      (concept-goto-current-focus)
      (next-line)
      (let ((seen (make-hash-table :test #'equal))
            resource)
        (while (not (concept-on-focus-line))
          (when (concept-on-resource-line)
            (setq resource (concept-current-resource))
            (unless (gethash resource seen)
              (puthash resource t seen)))
          (next-line))
        (hash-table-count seen)))))

(defun concept-insert-relationship-block (focus relationship concept)
  "Insert a new relationship block before the current line."
  (let ((line-move-visual nil))
    (previous-line)
    (end-of-line)
    (newline)
    (insert "~ ")
    (insert focus)
    (newline)
    (insert "| :")
    (insert relationship)
    (newline)
    (insert "| ")
    (insert concept)))

(defun concept-breakout-relationship-at-point ()
  "Separate the current data concept into it's own relationship block."
  (interactive)
  (when (and (concept-on-data-line)
             (concept-on-concept-line))
    (let ((last-rel (concept-last-relationship))
          (last-con (concept-last-concept))
          (curr-con (concept-current-concept)))
      (beginning-of-line)
      (kill-line)
      (kill-line)
      (concept-goto-next-concept)
      (concept-insert-relationship-block last-con last-rel curr-con))))

(defun concept-split-relationships-at-point ()
  "Separate each relationship in the current block into its own block.
Place each relationship into its own block."
  (interactive)
  (when (concept-in-relationship-block)
    (concept-goto-current-focus)
    (concept-goto-next-concept)
    (while (< 1 (concept-relationship-count))
      (if (and (concept-on-data-line)
               (concept-on-concept-line))
          (concept-breakout-relationship-at-point)
        (concept-goto-next-concept)))))

(defun concept-insert-concept-dwim (arg)
  "Insert a concept in the position if it makes sense."
  (interactive "P")
  (let ((k (if (numberp arg) arg 0)))
    (if (concept-on-focus-line)
        (if (concept-on-last-concept)
            (concept-insert-last-concept-as-focus)
          (concept-insert-next-concept-as-focus k))
      (if (concept-on-last-concept)
          (concept-insert-last-concept-as-new k)
        (concept-insert-next-concept-as-data-2 k)))))

(defun concept-split-dwim ()
  "Split the relationship block up into two ideas."
  (interactive)
  (cond ((and (concept-on-first-data-concept-line-in-block)
              (save-excursion
                (forward-line)
                (concept-on-focus-line)))
         (concept-swap-data-with-focus))
        ((and (concept-on-focus-line)
              (eq 1 (concept-relationship-count)))
         (concept-swap-focus-with-first-data))
        ((and (concept-on-data-line)
              (concept-on-concept-line)
              (save-excursion
                (forward-line)
                (and (concept-on-data-line)
                     (concept-on-concept-line))))
         (when (not (concept-on-blank-line))
           (let ((focus (concept-current-focus))
                 (relationship (concept-current-relationship)))
             (end-of-line)
             (newline)
             (insert "~ ")
             (insert focus)
             (newline)
             (insert "| :")
             (insert relationship))))))

(defun concept-data-split-dwim ()
  "Split the relationship block up into two ideas."
  (interactive)
  (cond ((and (concept-on-data-concept-line)
              (save-excursion
                (forward-line)
                (concept-on-data-concept-line)))
           (when (not (concept-on-blank-line))
             (let ((concept (concept-current-concept))
                   (relationship (concept-current-relationship)))
               (end-of-line)
               (newline)
               (insert "~ ")
               (insert concept)
               (newline)
               (insert "| :")
               (insert relationship))))))

(defun concept-swap-data-with-focus ()
  (interactive)
  (when (concept-on-data-concept-line)
    (let ((focus (concept-current-focus))
          (data  (concept-current-concept)))
      (backward-sexp)
      (kill-line)
      (insert focus)
      (concept-goto-current-focus)
      (backward-sexp)
      (kill-line)
      (insert data))))

(defun concept-on-first-data-concept-line-in-block ()
  "Test if the current line is the first data concept line."
  (and (concept-on-data-concept-line)
       (save-excursion
         (previous-line)
         (concept-on-first-relationship-line))))

(defun concept-on-first-data-concept-line ()
  "Test if the current line is the first data concept line."
  (and (concept-on-data-concept-line)
       (save-excursion
         (previous-line)
         (concept-on-relationship-line))))

(defun concept-swap-focus-with-first-data ()
  (let ((focus (concept-current-focus))
        (data  (save-excursion
                 (concept-goto-next-concept)
                 (concept-current-concept))))
    (backward-sexp)
    (kill-line)
    (insert data)
    (concept-goto-next-concept)
    (backward-sexp)
    (kill-line)
    (insert focus)))

(defun concept-isolate-dwim ()
  "Isolate the current thing into it's own block."
  (interactive)
  (cond
   ((and (concept-on-first-data-concept-line-in-block)
         (save-excursion
           (forward-line)
           (concept-on-focus-line)))
    (concept-swap-data-with-focus))
   ((and (concept-on-focus-line)
         (eq 1 (concept-relationship-count)))
    (concept-swap-focus-with-first-data))
   ((and (concept-on-data-concept-line)
                (or (save-excursion
                      (forward-line)
                      (concept-on-data-concept-line))
                    (save-excursion
                      (previous-line)
                      (concept-on-data-concept-line))))
           (when (not (concept-on-blank-line))
             (let ((focus (concept-current-focus))
                   (relationship (concept-current-relationship))
                   (concept (concept-current-concept)))
               (kill-whole-line)
               (concept-goto-current-focus)
               (beginning-of-line)
               (newline)
               (previous-line)
               (insert "~ ")
               (insert focus)
               (newline)
               (insert "| :")
               (insert relationship)
               (newline)
               (insert "| " concept))))
        ((and (concept-on-exposition-line)
              (or (save-excursion
                    (forward-line)
                    (concept-on-exposition-line))
                  (save-excursion
                    (previous-line)
                    (concept-on-exposition-line))))
         (let ((resource (concept-current-resource-name))
               (keyword  (concept-current-attribute))
               (data     (concept-current-line)))
           (kill-whole-line)
           (concept-goto-current-resource)
           (previous-line)
           (end-of-line)
           (newline)
           (insert "@ " resource)
           (newline)
           (insert "| " keyword ":")
           (newline)
           (insert data)))))

(defun concept-insert-include-dwim (&optional prompt)
  "Do thing action which makes the most sense in the given concept editing situation.
If on a focused concept, then insert an :include line. Otherwise insert a blank data line."
  (interactive "P")
  (let ((relationship
         (if prompt
             (string-trim (read-string "Relationship: " "" t "include"))
           "include"))
        (line-move-visual nil))
    (cond ((concept-on-resource-line)
           (concept-insert-note-block))
          ((concept-on-attribute-line)
           (end-of-line)
           (newline)
           (insert "| {}")
           (backward-char))
          ((and (concept-on-exposition-line)
                (or (concept-on-last-line-in-block-p)
                    (save-excursion
                      (ignore-errors
                        (forward-line)
                        (concept-on-attribute-line)))))
           (end-of-line)
           (newline)
           (insert "| {}")
           (backward-char))
          ((and (concept-on-exposition-line)
                (save-excursion
                  (ignore-errors
                    (forward-line)
                    (concept-on-exposition-line))))
           (end-of-line)
           (newline)
           (insert "| note:"))
          ((and (concept-on-focus-line)
                (concept-on-blank-line))
           (if (concept-on-first-concept)
               (concept-insert-next-concept-as-focus 0)
             (concept-insert-last-concept-as-focus)))
          ((concept-on-focus-line)
           (when (concept-on-last-line-p)
             (end-of-line)
             (newline)
             (previous-line)
             (end-of-line))
           (when (not (save-excursion
                        (forward-line)
                        (concept-on-relationship-line)))
             (concept-insert-include-line)
             (newline)
             (insert "| "))
           (when (save-excursion
                   (forward-line)
                   (concept-on-relationship-line))
             (forward-line)
             (end-of-line)
             (concept-goto-next-relationship-boundary)
             (backward-char)))
          ((and (concept-on-data-line)
                (concept-on-concept-line)
                (save-excursion
                  (forward-line)
                  (and (concept-on-data-line)
                       (concept-on-concept-line))))
           (when (not (concept-on-blank-line))
               (end-of-line)
               (newline)
               (insert "| ")))
          ((concept-on-data-line)
           (when (concept-on-last-line-p)
             (end-of-line)
             (newline)
             (previous-line))
           (if (concept-on-blank-line)
               (if (concept-in-relationship-block)
                   (if (save-excursion
                         (previous-line)
                         (concept-on-focus-line))
                       (insert ":")
                     (concept-insert-concept-as-data))
                 (if (save-excursion
                       (previous-line)
                       (concept-on-resource-line))
                     (progn
                       (insert ":")
                       (backward-char 1))
                   (progn
                     (insert "{}")
                     (backward-char 1))))
             (concept-add-new-data)))
          (t
           (progn
             (concept-insert-relationship-line relationship)
             (when (save-excursion
                     (next-line)
                     (not (concept-on-data-line)))
               (concept-add-new-data)))))))

(defun concept-find-all-concept-words ()
  "Find all unique words in the concept map."
  (let ((seen (make-hash-table :test #'equal))
        words)
    (dolist (concept (concept-find-all-concepts))
      (dolist (word (split-string concept "-" t))
        (unless (gethash word seen)
          (puthash word t seen)
          (push word words))))
    (sort (nreverse words))))

(defun concept-last-word (x)
  "Find the last word in the string."
  (substring x (string-match "[^-]+$" x) (length x)))

(defun concept--setup-hippie-expand ()
  "Choose the appropriate hippe expansions for a concept mode files.
I only want to complete this way for words which are already
defined in the file. This will make sure authors keep things
simple."
  (setq-local hippie-expand-try-functions-list
              '(concept-try-expand-concept-fragment)))

(defvar-local concept-he-candidates-cache nil)

(defun concept-try-expand-concept-fragment (old)
  "Expand a concept fragment using words already defined in the file."
  (when (concept-on-concept-line)
    (unless old
      (setq concept-he-candidates-cache nil)
      (let ((bounds (bounds-of-thing-at-point 'word)))
        (when bounds
          (he-init-string (car bounds) (cdr bounds))
          (let ((fragment he-search-string))
            (setq concept-he-candidates-cache
                   (seq-filter
                    (lambda (word)
                      (and (not (string= word fragment))
                           (string-prefix-p fragment word)))
                    (concept-find-all-concept-words)))))))
    (when-let ((candidate (pop concept-he-candidates-cache)))
      (he-substitute-string candidate)
      t)))

(defun concept-fix-resource-blocks ()
  "Remove common mistakes in resource blocks."
  (save-excursion
    (goto-char (point-min))
    (while (concept-map-has-more-resources)
      (re-search-forward "^@")
      (while (and (concept-in-resource-block)
                  (not (eobp)))
        (forward-line)
        (when (and (concept-in-resource-block)
                   (not (concept-on-resource-line))
                   (not (concept-on-exposition-line))
                   (not (concept-on-attribute-line)))
          (let ((text
                 (buffer-substring-no-properties
                  (line-beginning-position) (line-end-position))))
            (end-of-line)
            (cond ((and (string-match-p "^| +{" text)
                        (not (string-match-p "} *$" text)))
                   (insert "}"))
                  ((and (string-match-p "^| +\\[" text)
                        (not (string-match-p "\\] *$" text)))
                   (insert "]"))
                  ((and (string-match-p "^| +‘" text)
                        (not (string-match-p "’ *$")))
                   (insert "’"))
                  ((string-match-p "^| +[^][{}‘’: ]+ *$" text)
                   (insert ":")))))))))

(defun concept-delete-leading-whitespace (beg end)
  "Remove whitespace before the usual starting tokens in a concept map."
  (interactive "r")
  (replace-regexp-in-region "^[[:blank:]]+" "" beg end))

(defun concept-delete-leading-text (beg end)
  "Remove all text before the usual starting tokens in a concept map."
  (interactive "r")
  (replace-regexp-in-region "^[^@~|]+" "" beg end))

(defun concept-cleanup-map ()
  "Remove whitespace, blank lines, and fix common mistakes with resource blocks."
  (interactive)
  (delete-trailing-whitespace)
  (delete-blank-lines)
  (concept-delete-leading-text)
  (concept-fix-resource-blocks))

(defun concept--delq-nth (n list)
  "Destructively remove the nth item of a list
Also remove every other element of the list which looks the same."
  (when (or (< n 0) (< (length list) n))
    (user-error "Index out of bounds!"))
  (let ((element (nth n list)))
    (delq element list)))

(defun concept--setup-niceties-including-hippie-expand ()
  "Setup hippie expand for concept maps."
  (setq-local dabbrev-case-replace nil)
  (concept--setup-hippie-expand)
  (local-set-key (kbd "M-q") #'ignore))

(add-hook 'concept-mode-hook #'concept--setup-niceties-including-hippie-expand)

(defun concept-insert-unicode-quote-brackets ()
  "Insert unicode quote brackets.
These brackets can hold just about any kind of data."
  (interactive)
  (end-of-line)
  (insert "‘’")
  (backward-char 1))

(defun concept-relationship-keyword-count ()
  "Count the number of relationship keywords inside a concept block."
  (save-excursion
    (save-restriction
      (concept-narrow-to-concept-block)
      (goto-char (point-min))
      (let ((count 0))
        (while
            (and (not (concept-on-last-line-p))
                 (concept-in-relationship-block))
          (concept-goto-next-relationship)
          (when (concept-on-relationship-line)
            (setq count (1+ count))))
        count))))

(defun concept-expand-combinatorial-relationship-block ()
  "Expand a combinatorial block."
  (interactive)
  (let ((line-move-visual nil))
    (when (and (concept-in-relationship-block)
               (= 3 (concept-relationship-count))
               (= 1 (concept-relationship-keyword-count)))
      (save-restriction
        (concept-narrow-to-concept-block)
        (concept-goto-current-focus)
        (next-line)
        (beginning-of-line)
        (forward-char 2)
        (when (not (looking-at-p ":include"))
          (error "Not an include relationship!"))
        (concept-goto-next-concept)
        (save-excursion
          (beginning-of-line)
          (forward-char 2)
          (let ((p (point)))
            (concept-repeat-dwim)
            (concept-insert-include-dwim)
            (let ((q (point)))
              (goto-char p)
              (next-line 2)
              (beginning-of-line)
              (forward-char 2)
              (kill-ring-save (point) (line-end-position))
              (goto-char q)
              (yank))))
        (concept-goto-next-concept)
        (save-excursion
          (beginning-of-line)
          (forward-char 2)
          (let ((p (point)))
            (concept-repeat-dwim)
            (concept-insert-include-dwim)
            (let ((q (point)))
              (goto-char p)
              (next-line 1)
              (beginning-of-line)
              (forward-char 2)
              (kill-ring-save (point) (line-end-position))
              (goto-char q)
              (yank))))
        (concept-goto-next-concept)
        (beginning-of-line)
        (kill-line)
        (kill-line))
      (flush-lines "^$")
      (outline-forward-same-level 1)
      (outline-end-of-subtree))))

(defvar-local concept-last-relationship-size nil
  "Most recently used relationship-block size.")

(defun  concept-goto-next-relationship-block-of-size (prefix)
  "Search for relationship blocks with certain numbers of relationships.
This is useful for finding combinatorial relationships. See also the
previous version."
  (interactive "P")
  (let* ((count 0)
         (default (and concept-last-relationship-size
                       concept-last-relationship-size))
         (size
          (if prefix
              (prefix-numeric-value prefix)
            (read-number (format "Relationships (%S): "
                                 (symbol-name concept-last-size-comparison-behavior))
                         concept-last-relationship-size))))
    (ignore-errors
      (outline-up-heading 1))
    (ignore-errors
      (outline-forward-same-level 1))
    (setq concept-last-relationship-size size)
    (setq count (concept-relationship-count))
    (while (and (not (concept-on-last-line-p))
                (not (concept-make-last-size-comparison count size)))
      (ignore-errors
        (outline-forward-same-level 1))
      (setq count (concept-relationship-count)))
    (concept-goto-current-focus)))

(defvar-local concept-last-relationship-group-size nil
  "Navigate relationship blocks according the number of relationship groups.")

(defvar-local concept-last-relationship-group-unique nil
  "Whether to consider the grouping as unique or not.")

(defvar-local concept-last-relationship-group-size-behavior 'all
  "Whether to consider the relationship grouping as `all', `unique', or `diff'.")

(defvar-local concept-last-resource-count-behavior 'all
  "Whether to consider the resource grouping as `all', `unique', or `diff'.")

(defun  concept-goto-next-relationship-block-with-group-size (prefix)
  "Search for relationship blocks with certain numbers of relationship
groups. This is useful for finding combinatorial relationships. See also
the previous of this command which goes (backwards) in the other direction."
  (interactive "P")
  (let* ((count 0)
         ;; If it's defined, store the value
         (default (and concept-last-relationship-group-size
                       concept-last-relationship-group-size))
         (size
          (if prefix
              (prefix-numeric-value prefix)
            (read-number
             (format "Relationship Groups (%S, %S): "
                     (symbol-name concept-last-size-comparison-behavior)
                     concept-last-relationship-group-size-behavior)
             concept-last-relationship-group-size))))
    (ignore-errors
      (outline-up-heading 1))
    (ignore-errors
      (outline-forward-same-level 1))
    (setq concept-last-relationship-group-size size)
    (setq count (concept-make-relationship-block-group-size-count))
    (let ((starting-line (line-number-at-pos))
          current-line)
      (while (and (not (concept-on-last-line-p))
                  (not (concept-make-last-size-comparison count size))
                  (not (eobp)))
        (ignore-errors
          (outline-forward-same-level 1))
        (setq current-line (line-number-at-pos))
        (when (eq starting-line current-line)
          (user-error "Now in last relationship block. No more to search. Aborting!"))
        (setq starting-line current-line)
        (setq count (concept-make-relationship-block-group-size-count)))
      (re-search-forward "^| +:" nil t)
      (end-of-line))))

(defun concept-make-relationship-block-group-size-count ()
  "Make the desired relationship group size count."
  (cond ((eq concept-last-relationship-group-size-behavior 'all)
         (concept-relationship-group-count))
        ((eq concept-last-relationship-group-size-behavior 'unique)
         (concept-unique-relationship-group-count))
        ((eq concept-last-relationship-group-size-behavior 'diff)
         (- (concept-relationship-group-count)
            (concept-unique-relationship-group-count)))
        (t (error "Unknown relationship group size state! Please stick to all, unique, or diff."))))

(defun concept-goto-previous-relationship-block-with-group-size (prefix)
  "Search for relationship blocks with certain numbers of relationship
groups. This is useful for finding combinatorial relationships. See also
the previous of this command which goes (backwards) in the other direction.

The meaning of `group-size' depends on the value of
`concept-last-relationship-group-size-behavior'. However, I still have
to implement that functionality."
  (interactive "P")
  (let* ((count 0)
         (default (and concept-last-relationship-group-size
                       concept-last-relationship-group-size))
         (size
          (if prefix
              (prefix-numeric-value prefix)
            (read-number (format "Relationship Groups (%S, %S): "
                                 (symbol-name concept-last-size-comparison-behavior)
                                 concept-last-relationship-group-size-behavior)
                         concept-last-relationship-group-size))))
    (ignore-errors
      (outline-up-heading 1))
    (ignore-errors
      (outline-backward-same-level 1))
    (setq concept-last-relationship-group-size size)
    (setq count (concept-relationship-block-group-size-count))
    (let ((starting-line (line-number-at-pos))
          current-line)
      (while (and (not (concept-on-last-line-p))
                  (not (concept-make-last-size-comparison count size))
                  (not (eobp)))
        (ignore-errors
          (outline-backward-same-level 1))
        (setq current-line (line-number-at-pos))
        (when (eq starting-line current-line)
          (user-error "Now in last relationship block. No more to search. Aborting!"))
        (setq starting-line current-line)
        (setq count (concept-relationship-block-group-size-count)))
    (re-search-forward "^| +:" nil t)
    (end-of-line))))

(defvar-local concept-last-resource-count nil
  "Search based on the number of resource blocks in a relationship block.")

(defun concept-goto-next-relationship-block-with-resource-count (prefix)
  "Search for relationship blocks with certain numbers of resource
blocks. See also the previous variant of this command which
goes (backwards) in the other direction."
  (interactive "P")
  (let* ((count 0)
         (default (and concept-last-resource-count
                       concept-last-resource-count))
         (size
          (if prefix
              (abs (prefix-numeric-value prefix))
            (read-number (format "Resource Blocks (%s, %s): "
                                 (symbol-name concept-last-size-comparison-behavior)
                                 (symbol-name concept-last-resource-count-behavior))
                         concept-last-resource-count))))
    (ignore-errors
      (outline-up-heading 1))
    (ignore-errors
      (outline-forward-same-level 1))
    (setq concept-last-resource-count size)
    (setq count (concept-make-last-resource-count))
    (while (and (not (concept-on-last-line-p))
                (not (concept-make-last-size-comparison count size))
                (not (eobp)))
      (ignore-errors
        (outline-forward-same-level 1))
      (setq count (concept-make-last-resource-count)))
    (concept-goto-current-focus)
    (when (eql count size)
      (re-search-forward "^@" nil t))
    (end-of-line)))

(defvar-local concept-last-attribute-count nil
  "Number of keyword attributes.")

(defvar-local concept-last-attribute-count-behavior 'all
  "Pick the attribute count of interest.
Either `all', `unique', or `diff'. `diff' means the difference between
`all' and `unique'. Note that this functionality totals up all the
attributes in all the resource blocks under the given idea.")

(defun concept-set-last-attribute-count-behavior ()
  "Set the desired behavior for counting attribute keywords associated with
a relationship block."
  (interactive)
  (let ((choice (read-multiple-choice "Select an option for attribute count behavior"
                                      '((?a "All" "Count all keywords")
                                        (?b "Unique" "Count only unique keywords")
                                        (?c "Diff" "Difference between all and unique")))))
    (pcase (car choice)
      (?a (setq-local concept-last-attribute-count-behavior 'all))
      (?b (setq-local concept-last-attribute-count-behavior 'unique))
      (?c (setq-local concept-last-attribute-count-behavior 'diff)))
    (message "Setting `concept-last-attribute-count-behavior' to `%S'."
             concept-last-attribute-count-behavior)))

(defun concept-set-last-relationship-size-behavior ()
  "Set the desired behavior for counting relationship keywords associated with
a relationship block. See also `concept-set-last-attribute-count-behavior'."
  (interactive)
  (let ((choice (read-multiple-choice "Select an option for relationship count behavior"
                                      '((?a "All" "Count all keywords")
                                        (?b "Unique" "Count only unique keywords")
                                        (?c "Diff" "Difference between all and unique")))))
    (pcase (car choice)
      (?a (setq-local concept-last-relationship-group-size-behavior 'all))
      (?b (setq-local concept-last-relationship-group-size-behavior 'unique))
      (?c (setq-local concept-last-relationship-group-size-behavior 'diff)))
    (message "Setting `concept-last-relationship-group-size-behavior' to `%S'."
             concept-last-relationship-group-size-behavior)))

(defun concept-set-last-resource-count-behavior ()
  "Set the desired behavior for counting attribute keywords associated with
a relationship block. See also `concept-set-last-attribute-count-behavior'."
  (interactive)
  (let ((choice (read-multiple-choice "Select an option for resource count behavior"
                                      '((?a "All" "Count all keywords")
                                        (?b "Unique" "Count only unique keywords")
                                        (?c "Diff" "Difference between all and unique")))))
    (pcase (car choice)
      (?a (setq-local concept-last-resource-count-behavior 'all))
      (?b (setq-local concept-last-resource-count-behavior 'unique))
      (?c (setq-local concept-last-resource-count-behavior 'diff)))
    (message "Setting `concept-last-resource-count-behavior' to `%S'."
             concept-last-resource-count-behavior)))

(defvar concept-last-size-comparison-behavior
  '=
  "Determine how comparisons based on relevant sizes of ideas are made.
 Allowed values are '=, '<=, and '>")

(defun concept-set-last-size-comparison-behavior ()
  "Set the desired behavior for comparing sizes in a concept map.
This modifies the global variable `concept-last-size-comparison-behavior'."
  (interactive)
  (let ((choice (read-multiple-choice "Select an option for size comparison behavior"
                                      '((?a "="  "Keep idea sizes which match exactly")
                                        (?b "<=" "Keep sizes less than or equal to")
                                        (?c ">"  "Keep sizes greater than the level")))))
    (pcase (car choice)
      (?a (setq-local concept-last-size-comparison-behavior '=))
      (?b (setq-local concept-last-size-comparison-behavior '<=))
      (?c (setq-local concept-last-size-comparison-behavior '>)))
    (message "Setting `concept-last-size-comparison-behavior' to `%S'."
             concept-last-size-comparison-behavior)))

(defun concept-resource-keyword-count ()
  "Count the number of keywords associated with a resource."
  (when (concept-in-resource-block)
    (save-excursion
      (concept-goto-current-resource)
      (re-search-forward concept-attribute-group-name-regexp nil t)
      (let ((n 1))
        (while (concept-on-attribute-line)
          (concept-goto-next-attribute-boundary)
          (end-of-line)
          (when (concept-on-attribute-line)
            (setq n (1+ n))))
        n))))

(defun concept-make-last-attribute-count ()
  "Dispatch to the right procedure for counting attributes.
Note that attributes counts are summed across all resource blocks inside
the idea."
  (cond ((eq concept-last-attribute-count-behavior 'all)
         (concept-relationship-block-attribute-count))
        ((eq concept-last-attribute-count-behavior 'unique)
         (concept-unique-relationship-block-attribute-count))
        ((eq concept-last-attribute-count-behavior 'diff)
         (- (concept-relationship-block-attribute-count)
            (concept-unique-relationship-block-attribute-count)))
        (t (error "Unknown attribute count state! Please stick to all, unique, or diff."))))

(defun concept-make-last-resource-count ()
  "Dispatch to the right procedure for counting resources.
Note that resource counts are totalled by ideas."
  (cond ((eq concept-last-resource-count-behavior 'all)
         (concept-resource-block-count))
        ((eq concept-last-resource-count-behavior 'unique)
         (concept-unique-resource-block-count))
        ((eq concept-last-resource-count-behavior 'diff)
         (- (concept-resource-block-count)
            (concept-unique-resource-block-count)))
        (t (error "Unknown resource count state! Please stick to 'all, 'unique, or 'diff."))))

(defun concept-make-last-size-comparison (a b)
  "Dispatch to the right procedure for comparing idea sizes."
  (cond ((eq concept-last-size-comparison-behavior '=)
         (equal a b))
        ((eq concept-last-size-comparison-behavior '<=)
         (<= a b))
        ((eq concept-last-size-comparison-behavior '>)
         (< b a))
        (t (error "Unknown size comparison behavior! Please stick to '=, '<=, or '>."))))

(defun concept-goto-next-relationship-block-with-attribute-count (prefix)
  "Search for relationship blocks with certain numbers of keyword
attributes summed across all containing resource blocks. See also the
previous of this command which goes (backwards) in the other direction.

By running the command `concept-set-last-attribute-count-behavior', the
user can change the behavior of this function in order to find
relationship blocks with different interesting properties. There are
three of them at the moment. They are documented in that command. These
are the same options which make sense for
`concept-set-last-relationship-size-behavior' as well."
  (interactive "P")
  (let* ((count 0)
         (default (and concept-last-attribute-count
                       concept-last-attribute-count))
         (size
          (if prefix
              (prefix-numeric-value prefix)
            (read-number (format "Keyword Count (%S, %S): "
                                 (symbol-name concept-last-size-comparison-behavior)
                                 concept-last-attribute-count-behavior)
                         concept-last-attribute-count))))
    (ignore-errors
      (outline-up-heading 1))
    (ignore-errors
      (outline-forward-same-level 1))
    (setq concept-last-attribute-count size)
    (setq count (concept-make-last-attribute-count))
    (while (and (not (concept-on-last-line-p))
                (not (concept-make-last-size-comparison count size))
                (not (eobp)))
      (ignore-errors
        (outline-forward-same-level 1))
      (setq count (concept-make-last-attribute-count)))
    (concept-goto-current-focus)
    (when (and (< 0 size) (concept-make-last-size-comparison count size))
      (re-search-forward "^@" nil t)
      (re-search-forward ": *$"))
    (end-of-line)))

(defun concept-goto-previous-relationship-block-with-attribute-count (prefix)
  "Search for relationship blocks with certain numbers of keyword
attributes summed across all containing resource blocks. See also the
previous of this command which goes (backwards) in the other direction.

By running the command `concept-set-last-attribute-count-behavior', the
user can change the behavior of this function in order to find
relationship blocks with different interesting properties. There are
three of them at the moment. They are documented in that command. These
are the same options which make sense for
`concept-set-last-relationship-size-behavior' as well.

When a PREFIX argument is supplied, its absolute value is used to
determine the count boundary. The global variable
`concept-last-size-comparison-behavior' determines whether '=, '<=, or
'> are used."
  (interactive "P")
  (let* ((count 0)
         (default (and concept-last-attribute-count
                       concept-last-attribute-count))
         (size
          (if prefix
              (abs (prefix-numeric-value prefix))
            (read-number (format "Keyword Count (%S, %S): "
                                 (symbol-name concept-last-size-comparison-behavior)
                                 concept-last-attribute-count-behavior)
                         concept-last-attribute-count))))
    (ignore-errors
      (outline-up-heading 1))
    (ignore-errors
      (outline-backward-same-level 1))
    (setq concept-last-attribute-count size)
    (setq count (concept-make-last-attribute-count))
    (while (and (not (concept-on-last-line-p))
                (not (concept-make-last-size-comparison count size))
                (not (eobp)))
      (ignore-errors
        (outline-backward-same-level 1))
      (setq count (concept-make-last-attribute-count)))
    (concept-goto-current-focus)
    (when (and (< 0 size) (concept-make-last-size-comparison count size))
      (re-search-forward "^@" nil t)
      (re-search-forward ": *$"))
    (end-of-line)))

(defun concept-goto-previous-relationship-block-of-size (prefix)
  "Search for relationship blocks with certain numbers of relationships.
This is useful for finding combinatorial relationships. See also the
next version."
  (interactive "P")
  (let ((count 0)
        (size (if prefix
                  (abs (prefix-numeric-value prefix))
                (string-to-number
                 (read-string (format "Relationships (%S): "
                                      (symbol-name concept-last-size-comparison-behavior))
                              (number-to-string concept-last-relationship-size))))))
    (ignore-errors
      (outline-up-heading 1))
    (outline-backward-same-level 1)
    (setq count (concept-relationship-count))
    (while (and (not (concept-on-first-line-p))
                (not (concept-make-last-size-comparison count size)))
      (outline-backward-same-level 1)
      (setq count (concept-relationship-count)))
    (concept-goto-current-focus)))

(defun concept-goto-next-dwim (prefix)
  "Go to the next thing depending on what line you are currently on."
  (interactive "P")
  (outline-show-all)
  (when (concept-on-concept-line)
    (concept-goto-next-relationship-block-of-size prefix))
  (when (concept-on-relationship-line)
    (concept-goto-next-relationship-block-with-group-size prefix))
  (when (concept-on-resource-line)
    (concept-goto-next-relationship-block-with-resource-count prefix))
  (when (or (concept-on-attribute-line)
            (concept-on-exposition-line))
    (concept-goto-next-relationship-block-with-attribute-count prefix)))

(defun concept-goto-previous-dwim (prefix)
  "Go to the previous thing depending on what line you are currently on."
  (interactive "P")
  (outline-show-all)
  (when (concept-on-concept-line)
    (concept-goto-previous-relationship-block-of-size prefix))
  (when (concept-on-relationship-line)
    (concept-goto-previous-relationship-block-with-group-size prefix))
  (when (concept-on-resource-line)
    (concept-goto-previous-relationship-block-with-resource-count prefix))
  (when (or (concept-on-attribute-line)
            (concept-on-exposition-line))
    (concept-goto-previous-relationship-block-with-attribute-count prefix)))

(defun concept-map-has-more-resources ()
  "Check if there are more resources to search through in the concept map."
  (save-excursion
    (end-of-line)
    (re-search-forward "^@ +" nil t)))

(defun concept-map-has-more-resources-matching (first-parts)
  "Check if there are more resources to search through in the concept map."
  (save-excursion
    (end-of-line)
    (re-search-forward
     (concat
      "^@ +"
      (concept--form-partial-match first-parts)) nil t)))

(defun concept-map-has-more-keywords-matching (second-parts)
  "Check if there are more keywords matching second query parts."
  (save-excursion
    (end-of-line)
    (re-search-forward
     (concat
      "^| +"
      (concept--form-partial-match second-parts)
      ": *$") nil t)))

(defun concept-map-has-more-relationships-matching (second-parts)
  "Check if there are more relationships matching second query clauses."
  (save-excursion
    (end-of-line)
    (re-search-forward
     (concat
      "^| +:"
      (concept--form-partial-match second-parts) " *$") nil t)))

(defun concept-map-has-more-data-concepts-matching (third-parts)
  "check for data concepts which match third query clauses."
  (let ((re "[^{}‘’:~ ]*"))
    (save-excursion
      (end-of-line)
      (re-search-forward
       (concat
        "^| +"
        re
        (concept--form-partial-match third-parts)
        re
        " *$") nil t))))

(defun concept-map-has-more-concept-blocks ()
  "Check if there are more relationship blocks to search through in the concept map."
  (save-excursion
    (end-of-line)
    (re-search-forward "^~ +" nil t)))

(defun concept-map-has-more-attributes ()
  "Return non-nil if a later attribute line exists."
  (save-excursion
    (end-of-line)
    (re-search-forward concept-attribute-group-line-lite-regexp nil t)))

(defun concept-map-has-more-relationships ()
  "Return non-nil if a later relationship line exists."
  (save-excursion
    (end-of-line)
    (re-search-forward concept-relationship-group-line-lite-regexp nil t)))

(defun concept-get-expository-data ()
  "Get the data on the line at point."
  (when (not (derived-mode-p 'concept-mode))
    (user-error  "This function was called outside of a concept map. Aborting!"))
  (let* ((line (concept-current-line))
         (start (string-match "[{[‘]" line))
         (end   (string-match "[]}’] *$" line)))
    (save-excursion
      (substring-no-properties line (1+ start) end))))

(defun concept-get-attribute-data ()
  "Get all the attribute data as a list of strings.
See also `concept-get-attribute' which gives a single string and
`concept-get-child-concepts' which does a similar operation but for
relationships.."
  (when (concept-on-attribute-line)
    (save-excursion
      (next-line)
      (let ((data '()))
        (while (and (not (eobp))
                    (concept-on-exposition-line))
          (push (concept-get-expository-data) data)
          (forward-line))
        (nreverse data)))))

(defun concept-get-child-concepts ()
  "Get all the child concepts under a relationship as a list of strings.
See also `concept-get-attribute-data'."
  (save-excursion
    (next-line)
    (let ((data '()))
      (while (and (not (eobp))
                  (not (concept-on-relationship-line))
                  (concept-on-data-line))
        (let* ((line (concept-current-line))
               (start 2))
          (forward-line)
          (push (string-trim (substring-no-properties line start)) data)))
      data)))

(defun query-split (part)
  (let* ((pieces (concept--split-string-by-bare-tilde part))
         (pieces (mapcar #'string-trim pieces))
         (n (length pieces)))
    (cond
     ((= n 1) (list (nth 0 pieces) "" ""))
     ((= n 2) (list (nth 0 pieces) (nth 1 pieces) ""))
     ((= n 3) pieces)
     (t (error "Too many ~ separators in %S" part)))))

(defun keyword-query-eval (data part)
  "Test one resource query against DATA.
This fixes PART as one thing. The goal is that there should be atleast
one match for this part of the query.

If a keyword is not a match, then how do I return t for it?"
  (let ((keyword (car data))
        (resources (cadr data)))
    (unless (stringp keyword)
      (error "Expected a string: got %S" keyword))
    (unless (listp resources)
      (error "Expected a list: got %S" resources))
    (let* ((kv (query-split part))
           (keyword-pat   (nth 1 kv))
           (resource-pat  (nth 2 kv))
           (key-neg-p       (string-prefix-p "@" keyword-pat))
           (resource-neg-p  (string-prefix-p "@" resource-pat))
           (keyword-pat   (string-remove-prefix "@" keyword-pat))
           (resource-pat  (string-remove-prefix "@" resource-pat)))
      ;; If the key matches, then check if atleast one of the values
      ;; match.  In the case of a negative match, return nil
      ;; immediately.
      (and
       (let ((key-match (string-match-p keyword-pat keyword)))
         (if key-neg-p (not key-match) key-match))
       (if resource-neg-p
           (seq-every-p
            (lambda (resource)
              (not (string-match-p resource-pat resource)))
            resources)
         (seq-some
          (lambda (resource)
            (string-match-p resource-pat resource))
          resources))))))

(defun relationship-query-eval (block-name data part)
  "Test one relationship query against DATA.
This fixes PART as one thing. The goal is that there should be atleast
one match for this part of the query."
  (let ((a (car data))
        (f block-name)
        (d (cadr data)))
    (unless (stringp a)
      (error "Expected a string: got %S" a))
    (unless (listp d)
      (error "Expected a list: got %S" d))
    (let* ((kv (query-split part))
           (b  (nth 0 kv))
           (k  (nth 1 kv))
           (v  (nth 2 kv))
           (F  (string-prefix-p "@" b))
           (n  (string-prefix-p "@" k))
           (N  (string-prefix-p "@" v))
           (b  (string-remove-prefix "@" b))
           (k  (string-remove-prefix "@" k))
           (v  (string-remove-prefix "@" v)))
      (and (let ((M (string-match-p b f)))
             (if F (not M) M))
       (let ((m (string-match-p k a)))
             (if  n (not m) m))
           (seq-some
            (lambda (e)
              (let ((m (string-match-p v e)))
                (if N (not m) m)))
            d)))))

(defun concept-get-block-name ()
  "Get the block name"
  (if (or (concept-on-resource-line)
          (concept-on-focus-line))
      (save-excursion
        (beginning-of-line)
        (let* ((line  (concept-current-line))
               (start 2))
          (string-trim (substring-no-properties line start))))
    (save-excursion
      (outline-previous-heading)
      (concept-get-block-name))))

(defun resource-queries-succeeded (block-name attribute-data query-parts)
  "Simultaneously evaluate a set of regular expression queries for matches
against a resource block.

* A query gets evaluated part by part.
* Every part must succeed.
* Every part can hold a different negative pattern matching rule.
* Each of the three pattern clauses can have negative pattern matches.
* These are shared within parts.
* If all query clauses are positive and have atleast on pattern match, then return not nil.
* If some query clauses are negative and have pattern matches, then return
nil for the whole query immediately.
* If some query clauses are negative but none have matches, then return non-nil.

Let's think about some examples.

query u~a:u~q has two parts. For each part, the attribute query is
blank. It should match blocks where both question: and answer: keywords
are specified.

query d~@^pdf-page$:d~^page$ also has two parts. For each part, the
attribute query is blank. It should match blocks where page: is found
but pdf-page is not.

query d~guide~ecm has but one part. The attribute query is not blank. It
should match document blocks where there is a guide: keyword and it's
value matches the pattern ecm like: ecm3.
"
  (seq-every-p
   (lambda (part)
     (let* ((keywords  (delete-dups (mapcar #'car attribute-data)))
            (clauses   (query-split part))
            (blk-pat   (nth 0 clauses))
            (key-pat   (nth 1 clauses))
            (atr-pat   (nth 2 clauses))
            (blk-neg-p (string-prefix-p      "@" blk-pat))
            (key-neg-p (string-prefix-p      "@" key-pat))
            (atr-neg-p (string-prefix-p      "@" atr-pat))
            (blk-pat   (string-remove-prefix "@" blk-pat))
            (key-pat   (string-remove-prefix "@" key-pat))
            (atr-pat   (string-remove-prefix "@" atr-pat)))
       (and
        (not (string-match-p "\s+" blk-pat))
        (not (string-match-p "\s+" key-pat))
        (or (string-empty-p blk-pat)
            (let ((blk-match (string-match-p blk-pat block-name)))
              (if blk-neg-p  (not blk-match) blk-match)))
        (or (string-empty-p key-pat)
            (let ((keys-matched
                   (seq-some
                    (lambda (word)
                      (string-match-p key-pat word))
                    keywords)))
              (if key-neg-p (not keys-matched) keys-matched)))
        (or (string-empty-p atr-pat)
            (let ((atr-matched
                   (seq-some
                    (lambda (key-group)
                      (let ((key-attributes (nth 1 key-group))
                            (key-parent     (nth 0 key-group)))
                        (seq-some
                         (lambda (attribute)
                           ;; We shoudn't have to worry about negative
                           ;; parents since they should have failed the
                           ;; and-expression already.
                           (let ((parent-match (string-match-p key-pat key-parent))
                                 (child-match  (string-match-p atr-pat attribute)))
                             (and parent-match child-match)))
                         key-attributes)))
                    attribute-data)))
              (if atr-neg-p (not atr-matched) atr-matched))))))
   query-parts))

(defun relationship-queries-succeeded (block-name data query-parts)
  "Simultaneously evaluate a set of regular expression queries for matches
against a relationship block.

If all queries have valid pattern matches, then return non-nil. There
can be negative pattern matches."
  (seq-every-p
   (lambda (part)
     (let* ((relationships (delete-dups (mapcar #'car data)))
            (clauses   (query-split part))
            (blk-pat   (nth 0 clauses))
            (rel-pat   (nth 1 clauses))
            (dat-pat   (nth 2 clauses))
            (blk-neg-p (string-prefix-p      "@" blk-pat))
            (rel-neg-p (string-prefix-p      "@" rel-pat))
            (dat-neg-p (string-prefix-p      "@" dat-pat))
            (blk-pat   (string-remove-prefix "@" blk-pat))
            (rel-pat   (string-remove-prefix "@" rel-pat))
            (dat-pat   (string-remove-prefix "@" dat-pat)))
       (and
        (or (string-empty-p blk-pat)
            (let ((blk-match (string-match-p blk-pat block-name)))
              (if blk-neg-p  (not blk-match) blk-match)))
        (or (string-empty-p rel-pat)
            (let* ((rel-match-p (lambda (word) (string-match-p rel-pat word)))
                   (rel-matched (seq-some rel-match-p relationships)))
              (if rel-neg-p (not rel-matched) rel-matched)))
        (or (string-empty-p dat-pat)
            (let ((dat-matched
                   (seq-some
                    (lambda (rel-group)
                      (let* ((data-concepts  (nth 1 rel-group))
                             (rel-parent     (nth 0 rel-group))
                             (rel-match-p
                              (lambda (data-concept)
                                (let ((parent-match (string-match-p rel-pat rel-parent))
                                      (child-match  (string-match-p dat-pat data-concept)))
                                  (and parent-match child-match)))))
                        (seq-some rel-match-p data-concepts)))
                    data)))
              (if dat-neg-p (not dat-matched) dat-matched))))))
     query-parts))

(defun concept--at-prefixed-strings (string)
  "Detect at-prefixed strings."
  (string-match-p "^@[^@]+$" string))

(defun concept-take-positive-clause-data (take-fun parts)
  "Take the positive clause data from a query part.

Remove any regular expression anchors."
  (delete-dups
   (mapcar (lambda (x)
             (string-remove-suffix
              "$"
              (string-remove-prefix "^" x)))
           (seq-remove
            #'concept--at-prefixed-strings
            (seq-remove
             #'string-empty-p
             (mapcar take-fun parts))))))

(defun concept--count-matches (pattern str)
  (let ((count 0)
        (pos 0))
    (while (string-match pattern str pos)
      (setq count (1+ count))
      (setq pos (match-end 0)))
    count))

(defun concept--is-invalid-resource-query-p (query)
  "A query is valid if there are no spaces in the first two sections.

I am not sure about later sections."
  (or (string-empty-p query)
      (string-match-p "::"  query)
      (string-match-p "^:"  query)
      (string-match-p ":$"  query)
      (string-match-p "\s+" query)
      (string-match-p "@+:" query)
      (string-match-p "@$"  query)))

(defun concept--is-invalid-idea-query-p (query)
  "A query is valid if there are no spaces in the first two sections.

I am not sure about later sections."
  (or (string-empty-p              query)
      (string-match-p "::"         query)
      (string-match-p ";;"         query)
      (and (string-match-p ";"     query)
           (or (string-match-p ":" query)
               (string-match-p "~" query)))
      (string-match-p "^;$"        query)
      (string-match-p ":$"         query)
      (string-match-p "\s+"        query)
      (string-match-p "@+:"        query)
      (string-match-p "@+;"        query)
      (string-match-p "@$"         query)))

(defun concept--is-relationship-agnostic-idea-query-p (query)
  "Test if a search query is relationship agnostic.

These are specified using ; separators. If there is one query, then  the last character is a semi-colon."
  (and (string-match-p ";" query)
       (not (concept--is-invalid-idea-query-p query))))

(defvar search-resource-blocks-history nil
  "History for concept-search-resource-blocks command.")

(defun concept-search-resource-blocks (&optional first-match-only)
  "Search for resource blocks with certain key-value pairs.
The query syntax should look like: KEY1~VAL1:KEY2 which finds matching
resource blocks which have atleast two keys: one that matches the
pattern KEY1 and a different one which matches the pattern KEY2. For the
keys that match the pattern KEY1, check that their values have a
substring which matches the pattern VAL1. If so, then consider that
resource block a pattern match. This scans the whole concept for
matches.

Here are some example queries to illustrate solving interesting search tasks.

The query `doc~page~127:doc~guid~football' should find resources concerning
page 127 of the football guide.

Note that like `concept-search-concept-blocks' this takes a prefix
argument. When that prefix argument is `C-u' it conducts a search from
right after the current match. When that prefix argument is `C-u C-u' or
there is no prefix argument, or anything else, it starts the search from
the beginning of the buffer.
"
  (interactive)
  (when (null first-match-only)
    (setq first-match-only nil))
  (let ((query (read-string "Resource Query: " nil 'search-resource-blocks-history))
        (found-first-match nil))
    (when (concept--is-invalid-resource-query-p query)
      (error  "Invalid query syntax!"))
    (let* ((parts (split-string query ":" t))
           (first-parts
            (concept-take-positive-clause-data
             #'concept--substring-before-tilde parts))
           (second-parts
            (concept-take-positive-clause-data
             #'concept--substring-between-tildes parts))
           (matching-blocks '()))
      (save-excursion
        (if (or (null first-match-only)
                (eq first-match-only 16))
            (goto-char (point-min))
          (concept-goto-next-resource))
        (while (and (or (not first-match-only) (not found-first-match))
                    (concept-map-has-more-resources))
          (concept-goto-next-resource)
          (when first-parts
            (while (and (not (eobp))
                        (concept-map-has-more-resources)
                        (concept-map-has-more-resources-matching first-parts)
                        (concept-map-has-more-keywords-matching second-parts)
                        (or (not (concept-on-resource-line))
                            (not (concept-resource-line-matches-all first-parts))
                            (and second-parts
                                 (not (concept-resource-keywords-match-all second-parts)))))
              (concept-goto-next-resource-line-with-any-of first-parts)))
          (when (not first-parts)
            (while (and (not (eobp))
                        (concept-map-has-more-resources)
                        (concept-map-has-more-keywords-matching second-parts)
                        (or (not (concept-on-resource-line))
                            (and second-parts
                                 (not (concept-resource-keywords-match-all second-parts)))))
              (concept-goto-next-resource)))
          (save-excursion
            (save-restriction
              (concept-narrow-to-resource-block)
              (let ((block-name (concept-get-block-name))
                    (block-pt   (point-min))
                    (block-end  (point-max)))
                (unless (stringp block-name)
                  (error "Expected a string but got: %s" block-name))
                (concept-goto-next-attribute)
                (let ((attribute-data  '()))
                  (while (concept-on-attribute-line)
                    (let ((a (concept-get-attribute))
                          (d (concept-get-attribute-data)))
                      (push (list a d) attribute-data))
                    (if (concept-map-has-more-attributes)
                        (concept-goto-next-attribute)
                      (forward-line)))
                  (when (resource-queries-succeeded block-name attribute-data parts)
                    (setq found-first-match t)
                    (push
                     (cons block-pt block-name)
                     matching-blocks))))))))
      (nreverse matching-blocks))))

(defun concept--substring-before-tilde (string)
  (let ((pos (string-search "~" string)))
    (substring string 0 pos)))

(defun concept--substring-between-tildes (string)
  (let ((N (length (split-string string "~"))))
    (cond ((eq N 1) "")
          ((eq N 2) (substring string (1+ (string-search "~" string))))
          ((eq N 3)
           (let* ((before (string-search "~" string))
                  (after  (string-search "~" string (1+ before))))
             (substring string (1+ before) after)))
          (t (error "Too many ~ characters in the string!")))))

(defun concept--substring-final-clause (string)
    (let ((N (length (split-string string "~"))))
    (cond ((eq N 1) "")
          ((eq N 2) "")
          ((eq N 3)
           (let* ((before (string-search "~" string))
                  (after  (string-search "~" string (1+ before))))
             (substring string (1+ after))))
          (t (error "Too many ~ characters in the string!")))))

(defun concept--form-partial-match (items)
  (concat concept-group-name-restriction-regexp "*\\(?:"
          (mapconcat #'regexp-quote items "\\|")
          "\\)"
          concept-group-name-restriction-regexp "*"))

(defun concept-map-has-more-focus-lines-with-any-of (first-parts)
  "Check if there are more relationship blocks to search through in the concept map."
  (let ((re (concat "^~ +" (concept--form-partial-match first-parts))))
    (save-excursion
      (end-of-line)
      (re-search-forward re nil t))))

(defun concept-goto-next-focus-with-any-of (first-parts)
  "Move forward to initially promising focus lines."
  (let ((re (concat "^~ +" (concept--form-partial-match first-parts))))
    (end-of-line)
    (or
     (prog1
       (re-search-forward re nil t)
       (previous-line)
       (end-of-line))
     (goto-char (point-max)))))

(defun concept-goto-next-focus-with-data-like (third-parts)
  "Move forward to initially promising focus lines."
  (concept-goto-next-concept-block)
  (let ((re (concat "^| +" concept-group-name-restriction-regexp "*"
                    (concept--form-partial-match third-parts))))
    (end-of-line)
    (let ((match (re-search-forward re nil t)))
      (cond (match
             (beginning-of-line)
             (outline-previous-heading)
             (end-of-line))
            (t
             (goto-char (point-max)))))))

(defun concept-goto-next-focus-with-relationships-like (second-parts)
  "Move forward to initially promising focus lines."
  (concept-goto-next-concept-block)
  (let ((re (concat
             "^| +:" concept-group-name-restriction-regexp "*"
             (concept--form-partial-match second-parts))))
    (end-of-line)
    (let ((match (re-search-forward re nil t)))
      (cond (match
             (outline-previous-heading)
             (end-of-line))
            (t
             (goto-char (point-max)))))))

(defun concept-focus-line-matches-all (parts)
  "Look forward for multiple parts which much"
  (and (concept-on-focus-line)
       (seq-every-p
        (lambda (part)
          (save-excursion
            (beginning-of-line)
            (looking-at
             (concat "^~ +" concept-group-name-restriction-regexp "*"
                     (regexp-quote part) "[^: ]*"))))
        parts)))

(defun concept-resource-line-matches-all (parts)
  "Look forward for multiple parts which much"
  (and (concept-on-resource-line)
       (seq-every-p
        (lambda (part)
          (save-excursion
            (beginning-of-line)
            (looking-at
             (concat "^@ +" concept-group-name-restriction-regexp "*"
                     (regexp-quote part) "[^: ]*"))))
        parts)))

(defun concept-resource-keywords-match-all (second-parts)
  (when (concept-on-resource-line)
    (let ((attributes (concept-get-resource-block-attributes)))
      (seq-every-p
       (lambda (part)
         (seq-some
          (lambda (attrib) (string-match-p part attrib))
          attributes))
       second-parts))))

(defun concept-relationships-match-all (second-parts)
  (when (concept-on-focus-line)
    (let ((relationships (concept-get-concept-block-relationships)))
      (seq-every-p
       (lambda (part)
         (seq-some
          (lambda (relationship)
            (string-match-p part relationship))
          relationships))
       second-parts))))

(defun concept-data-concepts-match-all (third-parts)
  (when (concept-on-focus-line)
    (let ((data-concepts (concept-get-concept-block-data-concepts)))
      (seq-every-p
       (lambda (part)
         (seq-some
          (lambda (concept) (string-match-p part concept))
          data-concepts))
       third-parts))))

(defun concept-concepts-match-all (parts)
  "Get the focus concepts."
  (when (concept-on-focus-line)
    (let* ((focus    (concept-get-block-name))
           (data     (concept-get-concept-block-data-concepts))
           (concepts (cons focus data)))
      (seq-every-p
       (lambda (part)
         (seq-some
          (lambda (concept) (string-match-p part concept))
          concepts))
       parts))))

(defun concept-data-concepts-match-any (parts)
  "Test if any of the concepts match this stuff.
This is used to do things."
  (when (concept-on-focus-line)
    (let ((data-concepts (concept-get-concept-block-data-concepts)))
      (seq-some
       (lambda (part)
         (seq-some
          (lambda (concept) (string-match-p part concept))
          data-concepts))
       parts))))

(defun concept-concepts-match-any (parts)
  "Test if any of the concepts match this stuff.

This is used to do things."
  (when (concept-on-focus-line)
    (let* ((data  (concept-get-concept-block-data-concepts))
           (focus (concept-get-block-name))
           (concepts (cons focus data)))
      (seq-some
       (lambda (part)
         (seq-some
          (lambda (concept) (string-match-p part concept))
          concepts))
       parts))))

(defun concept--take-negative-idea-parts (parts)
  "Keep only the negative query parts and make them positive.

This is used to perform relationship agnostic idea queries."
  (mapcar
   (lambda (part) (string-remove-prefix "@" part))
   (seq-filter
    (lambda (part) (string-prefix-p "@" part)) parts)))

(defun concept--take-positive-idea-parts (parts)
  "Keep only the positive query parts.

This is used to perform relationship agnostic idea queries."
  (seq-filter
   (lambda (part) (not (string-prefix-p "@" part))) parts))

(defun concept-relationship-agnostic-idea-matches-p (query)
  "Perform a relationship agnostic idea search."
  (save-excursion
    (concept-goto-current-focus)
    (let ((parts (string-split query ";" t)))
    (if (not (string-match-p "@" query))
        (concept-concepts-match-all parts)
      (let ((neg (concept--take-negative-idea-parts parts))
            (pos (concept--take-positive-idea-parts parts)))
        (and (or (eq (length neg) 0)
                 (not (concept-concepts-match-any neg)))
             (or (eq (length pos) 0)
                 (concept-concepts-match-all pos))))))))

(defvar search-concept-blocks-history nil
  "History for concept-search-concept-blocks command.")

(defun concept-search-concept-blocks (&optional first-match-only)
  "Search for concept blocks with certain relationships or combinations of concepts.
With FIRST-MATCH-ONLY, return immediately after the first
match. Depending on the value of FIRST-MATCH-ONLY, start from either the
beginning of the buffer or the next idea after previous match.

For searching relationships, the query syntax should look like:
`CON1~REL1~CON2:~REL2~CON3:CON4~REL3:CON5' which finds matching resource
blocks which have atleast 5 concept name fragments and three
relationships. For the relevant concepts and relationships, check that
their values have matching substrings corresponding to each part of the
query. If so, then consider that concept block a pattern match. This
scans the whole concept for matches.

Here are some example queries to illustrate the solving interesting
search tasks.

The query `~incl~portion:~incl~part' should match concept blocks where
both portion and part are present simultaneously as part of
data concepts.

The query `~in~val' should match concept blocks where val is found in a
data concept and the relationship should have in.

The query `~in~par:~in~val' matches ideas with partial and fully data concepts.

The query `@ammu~~@ammu' matches all ideas that are not about ammunition
at all. This negative match can be quite slow for large concept maps
since the logic has to traverse each idea in turn.

The query `amm~~@amm' should match:

~ hammers
| :include
| mallets

But it should fail to match the query below (because of claw-hammers):

~ hammers
| :include
| claw-hammers
| mallets

The query `^variables$~in~env' should match ideas like:

~ variables
| :include
| environment-variables

For just searching through combinations of concepts we use `\;' as a separator instead.

The query `@amm\;' matches all query blocks with no amm anywhere inside them.

The query `old\;new' matches all query blocks involving matches for both old and new.

The query `old\;@new' matches all query blocks with old but not new terms.
"
  (interactive)
  (when (null first-match-only)
    (setq first-match-only nil))
  (let ((query (read-string  "Idea Query: " nil 'search-concept-blocks-history))
        (matching-blocks '())
        (found-first-match nil))
    (when (concept--is-invalid-idea-query-p query)
      (error "Invalid idea query syntax!"))
    (if (concept--is-relationship-agnostic-idea-query-p query)
        (save-excursion
          (if (or (null first-match-only)
                  (eq first-match-only 16))
              (goto-char (point-min))
            (concept-goto-next-focus))
          (while (and (or (not first-match-only)
                          (not found-first-match))
                      (concept-map-has-more-concept-blocks))
            (re-search-forward "^~" nil t)
            (let ((block-name (concept-get-block-name))
                  (block-pt   (line-beginning-position)))
              (when (concept-relationship-agnostic-idea-matches-p query)
                (setq found-first-match t)
                (push (cons block-pt block-name) matching-blocks)))
            (end-of-line)))
      (let* ((parts (split-string query ":" t))
             (first-parts
              (concept-take-positive-clause-data
               #'concept--substring-before-tilde parts))
             (second-parts
              (concept-take-positive-clause-data
               #'concept--substring-between-tildes parts))
             (third-parts
              (concept-take-positive-clause-data
               #'concept--substring-final-clause parts)))
        (save-excursion
          (if (or (null first-match-only)
                  (eq first-match-only 16))
              (goto-char (point-min))
            (concept-goto-next-focus))
          (while (and (or (not first-match-only)
                          (not found-first-match))
                      (concept-map-has-more-concept-blocks))
            (re-search-forward "^~" nil t)
            (if (or first-parts second-parts third-parts)
                (while (and (not (eobp))
                            (concept-map-has-more-concept-blocks)
                            (or (and first-parts
                                     (not (concept-focus-line-matches-all first-parts)))
                                (and second-parts
                                     (not (concept-relationships-match-all second-parts)))
                                (and third-parts
                                     (not (concept-data-concepts-match-all third-parts)))))
                  (cond (third-parts
                         (concept-goto-next-focus-with-data-like third-parts))
                        (first-parts
                         (concept-goto-next-focus-with-any-of first-parts))
                        (second-parts
                         (concept-goto-next-focus-with-relationships-like second-parts))))
              (while (and (not (eobp))
                          (concept-map-has-more-concept-blocks)
                          (not (concept-on-focus-line)))
                (concept-goto-next-concept-block)))
            (when (not (eobp))
              (save-restriction
                (concept-narrow-to-concept-block)
                (let ((block-name (concept-get-block-name))
                      (block-pt   (point-min))
                      (block-end  (point-max)))
                  (concept-goto-next-relationship)
                  (let ((relationship-data '()))
                    (while (concept-on-relationship-line)
                      (let ((r (concept-get-relationship))
                            (c (concept-get-child-concepts)))
                        (push (list r c) relationship-data))
                      (if (concept-map-has-more-relationships)
                          (concept-goto-next-relationship)
                        (forward-line)))
                    (when (relationship-queries-succeeded
                           block-name relationship-data parts)
                      (setq found-first-match t)
                      (push (cons block-pt block-name) matching-blocks))))))))))
    (nreverse matching-blocks)))

(put 'narrow-to-region 'disabled nil)

(defun concept-search-consult-resource-blocks ()
  "Pick a resource block with buffer preview."
  (interactive)
  (let* ((matches (concept-search-resource-blocks))
         (cands (mapcar #'car matches))
         (pos (consult--read
               cands
               :prompt "Resource block: "
               :sort nil
               :require-match t
               :state (consult--jump-state))))
    (when pos
      (goto-char pos)
      (save-restriction
        (widen)
        (concept-narrow-to-resource-block)))))

(defvar concept-consult--preview-overlay nil
  "This variable helps highlight the line during the consult search")

(defun concept--show-preview-line (pos)
  (when (overlayp concept-consult--preview-overlay)
    (delete-overlay concept-consult--preview-overlay))
  (save-excursion
    (goto-char pos)
    (setq concept-consult--preview-overlay
          (make-overlay (line-beginning-position) (line-end-position)))
    (overlay-put concept-consult--preview-overlay 'face 'highlight)))

(defun concept-consult-search-resource-blocks (arg)
  "Browse matching resource blocks with buffer preview."
  (interactive "P")
  (let ((buf (current-buffer))
        (found-first-match nil))
    (unwind-protect
        (let* ((matches (concept-search-resource-blocks arg))
               (alist (mapcar (lambda (m)
                                (cons (format "@ %s at position %d" (cdr m) (car m))
                                      (car m)))
                              matches))
               (choice
                (consult--read
                 (mapcar #'car alist)
                 :prompt "Resource block: "
                 :sort nil
                 :require-match t
                 :state (lambda (action cand)
                          (when (eq action 'preview)
                            (when-let ((pos (cdr (assoc cand alist))))
                              (with-current-buffer buf
                                (goto-char pos)
                                (concept--show-preview-line pos))))))))
          (when-let ((pos (cdr (assoc choice alist))))
            (with-current-buffer buf
              (goto-char pos)
              (save-restriction
                (widen)
                (concept-narrow-to-resource-block)))))
      (with-current-buffer buf
        (when (overlayp concept-consult--preview-overlay)
          (delete-overlay concept-consult--preview-overlay)
          (setq concept-consult--preview-overlay nil))))))

(defun concept-consult-search-concept-blocks (arg)
  "Browse matching concept blocks with buffer preview."
  (interactive "P")
  (let ((buf (current-buffer)))
    (unwind-protect
        (let* ((matches (concept-search-concept-blocks arg))
               (alist (mapcar (lambda (m)
                                (cons (format "~ %s at position %d" (cdr m) (car m))
                                      (car m)))
                              matches))
               (choice
                (consult--read
                 (mapcar #'car alist)
                 :prompt "Concept block: "
                 :sort nil
                 :require-match t
                 :state (lambda (action cand)
                          (when (eq action 'preview)
                            (when-let ((pos (cdr (assoc cand alist))))
                              (with-current-buffer buf
                                (goto-char pos)
                                (concept--show-preview-line pos))))))))
          (when-let ((pos (cdr (assoc choice alist))))
            (with-current-buffer buf
              (goto-char pos)
              (save-restriction
                (widen)
                (concept-narrow-to-concept-block)))))
      (with-current-buffer buf
        (when (overlayp concept-consult--preview-overlay)
          (delete-overlay concept-consult--preview-overlay)
          (setq concept-consult--preview-overlay nil))))))

(defun concept-copy-resource-at-point ()
  (interactive)
  (when (concept-in-resource-block)
    (save-restriction
      (concept-goto-last-resource-or-stay)
      (beginning-of-line)
      (let ((beg (point)))
        (outline-end-of-subtree)
        (let ((end (point)))
          (kill-new (buffer-substring beg end))
          (when (called-interactively-p)
            (message "Resource copied to kill ring")))))))

(defun concept-copy-all-resources ()
  "Copy all the resource blocks into the kill ring."
  (interactive)
  (save-excursion
    (beginning-of-buffer)
    (while (concept-map-has-more-resources)
      (concept-goto-next-resource)
      (concept-copy-resource-at-point))))

(defun concept-copy-idea-at-point ()
  "Copy all the idea blocks into the kill ring."
  (interactive)
  (save-restriction
    (ignore-errors
      (outline-up-heading 1))
    (beginning-of-line)
    (let ((beg (point)))
      (outline-end-of-subtree)
      (let ((end (point)))
        (kill-new (buffer-substring beg end))
        (when (called-interactively-p)
          (message "Idea copied to kill ring"))))))

(defun concept-copy-all-ideas ()
  (interactive)
  (save-excursion
    (beginning-of-buffer)
    (while (concept-map-has-more-concept-blocks)
      (concept-goto-next-concept-block)
      (concept-copy-idea-at-point))))

(defun concept-consult-yank-from-resources (string &optional arg)
  "Like `consult-yank-from-kill-ring', but uses a temporary kill-ring.
It copies the current kill-ring, clears it, fills it with buffer
resource data, runs the yank logic, then restores the original
kill-ring."
  (interactive (list nil current-prefix-arg))
  (let ((saved-kill-ring              (copy-sequence kill-ring))
        (saved-kill-ring-yank-pointer kill-ring-yank-pointer)
        (saved-yank-window-start      yank-window-start)
        (saved-this-command           this-command)
        (kill-ring-max                9999))
    (outline-end-of-subtree)
    (unless (looking-at-p "^[:space:]*$")
      (newline))
    (unwind-protect
        (progn
          (setq kill-ring nil
                kill-ring-yank-pointer nil)
          (concept-copy-all-resources)
          (setq string (consult--read-from-kill-ring))
          (when string
            (setq yank-window-start (window-start))
            (push-mark)
            (insert-for-yank string)
            (setq this-command 'yank)
            (when yank-from-kill-ring-rotate
              (if-let* ((pos (seq-position kill-ring string)))
                  (setq kill-ring-yank-pointer (nthcdr pos kill-ring))
                (kill-new string)))
            (when (consp arg)
              (goto-char (prog1 (mark t)
                           (set-marker (mark-marker) (point) (current-buffer)))))))
      ;; Restore original state.
      (delete-blank-lines)
      (setq kill-ring saved-kill-ring
            kill-ring-yank-pointer saved-kill-ring-yank-pointer
            yank-window-start saved-yank-window-start
            this-command saved-this-command))))

(defun concept-consult-yank-from-ideas (string &optional arg)
  "Like `consult-yank-from-kill-ring', but uses a temporary kill-ring.
It copies the current kill-ring, clears it, fills it with buffer
resource data, runs the yank logic, then restores the original
kill-ring."
  (interactive (list nil current-prefix-arg))
  (let ((saved-kill-ring (copy-sequence kill-ring))
        (saved-kill-ring-yank-pointer kill-ring-yank-pointer)
        (saved-yank-window-start yank-window-start)
        (saved-this-command this-command)
        (kill-ring-max 9999))
    (outline-end-of-subtree)
    (unless (looking-at-p "^[:space:]*$")
      (newline))
    (unwind-protect
        (progn
          (setq kill-ring nil
                kill-ring-yank-pointer nil)
          (concept-copy-all-ideas)
          (setq string (consult--read-from-kill-ring))
          (when string
            (setq yank-window-start (window-start))
            (push-mark)
            (insert-for-yank string)
            (setq this-command 'yank)
            (when yank-from-kill-ring-rotate
              (if-let* ((pos (seq-position kill-ring string)))
                  (setq kill-ring-yank-pointer (nthcdr pos kill-ring))
                (kill-new string)))
            (when (consp arg)
              (goto-char (prog1 (mark t)
                           (set-marker (mark-marker) (point) (current-buffer)))))))
      (delete-blank-lines)
      ;; Restore original state.
      (setq kill-ring saved-kill-ring
            kill-ring-yank-pointer saved-kill-ring-yank-pointer
            yank-window-start saved-yank-window-start
            this-command saved-this-command))))

(defun concept-next-double-heading ()
  "Find the next double heading in a concept map.
I had written a better function than this but lost it in file
corruption when my laptop lost power. This, however, is good
enough for now."
  (interactive)
  (let ((current-line (line-number-at-pos (point)))
        (max-lisp-eval-depth (count-lines (point-min) (point-max))))
    (forward-char)
    (if (search-forward-regexp "^~" nil t 1)
        (when (not (= (line-number-at-pos (point)) (+ current-line 1)))
          (concept-next-double-heading))
      (progn
        (goto-line 0)
        (concept-next-double-heading)))))

(defvar-local concept-eww-buffer-has-rendered nil
  "Check if EWW buffer has finished rendering.")

(defun concept-set-eww-buffer-as-rendered ()
  "Flag the current EWW buffer as having finished rendering."
  (setq-local concept-eww-buffer-has-rendered t))

(defun concept-eww-browse-url (url &optional new-window)
  "Ask the EWW browser to load URL but return the buffer.

This is a fork of `eww-browse-url'. It returns a reference to the
buffer it creates so that it can be subsequently manipulated.

Interactively, if the variable `browse-url-new-window-flag' is non-nil,
loads the document in a new buffer tab on the window tab-line.  A non-nil
prefix argument reverses the effect of `browse-url-new-window-flag'.

If `tab-bar-mode' is enabled, then whenever a document would
otherwise be loaded in a new buffer, it is loaded in a new tab
in the tab-bar on an existing frame.  See more options in
`eww-browse-url-new-window-is-tab'.

Non-interactively, this uses the optional second argument NEW-WINDOW
instead of `browse-url-new-window-flag'."
  (let ((url-allow-non-local-files t)
        (start-time (float-time)))
    (eww url)
    (add-hook 'eww-after-render-hook
              'concept-set-eww-buffer-as-rendered
              nil
              t)
    (while (and (not concept-eww-buffer-has-rendered)
                (< (- (float-time) start-time) 30))
      (accept-process-output nil 0.1)))
  (remove-hook 'eww-after-render-hook
               'concept-set-eww-buffer-as-rendered
               t)
  (current-buffer))

(defun concept-info-follow ()
  "Make an info-follow analogous to what man-follow does for man pages."
  (interactive)
  (when (concept-on-exposition-line)
    (let ((manual-name
           (concept-get-expository-data)))
      (when manual-name
        (info manual-name)))))

(defun concept-find-file ()
  "Find files on the current line."
  (interactive)
  (when (concept-on-exposition-line)
    (save-excursion
      (beginning-of-line)
      (re-search-forward "[^| ]" (line-end-position) t)
      (let ((beg (point)))
        (end-of-line)
        (re-search-backward "[^ ]" (line-beginning-position) t)
        (let* ((end (point))
               (name (buffer-substring-no-properties beg end)))
          (find-file name))))))

(defun concept-exposition-parent-key ()
  "Find the parent key to this key."
  (save-excursion
    (let ((pt (point)))
      (concept-goto-current-focus)
      (forward-line)
      (beginning-of-line)
      (let ((bnd (point)))
        (goto-char pt)
        (beginning-of-line)
        (when (re-search-backward concept-attribute-group-name-regexp bnd t)
          (string-trim (substring-no-properties (match-string 1))))))))

(defun concept--is-image-file (path)
  "Test if the file has an image file format Emacs recognizes."
  (condition-case err
      (image-type-from-file-name path)
    (err
     nil)))

(defun concept--is-pdf (path)
  "Test if the file looks like a PDF file."
  (string= "pdf" (downcase (file-name-extension path))))

(defun concept--is-file-binary-p (path)
  "Test if the file looks like a binary file."
  (string-match-p
   "charset=binary"
   (shell-command-to-string
    (format "file -i -- %s"
            (shell-quote-argument (expand-file-name path buffer-file-name))))))

(defun concept-describe-symbol-follow (symbol)
  "Follow *Help* buffers documenting Emacs symbols."
  (describe-symbol (intern symbol))
  (display-buffer (get-buffer "*Help*")))

(defun concept-describe-package-follow (package)
  "Follow *Help* buffers documenting Emacs symbols."
  (let ((pkg (intern package)))
    (if (or (package-installed-p pkg)
            (assq pkg package-archive-contents))
        (progn
          (describe-package pkg)
          (display-buffer (get-buffer "*Help*")))
      (message (format "The package (%s) is not available for this Emacs configuration." package)))))

(defun concept-describe-keybinding-follow (key)
  "Follow *Help* buffers documenting Emacs keybindings."
  (describe-key (kbd key))
  (display-buffer (get-buffer "*Help*")))

(defun concept-kill-all-elisp-evaluation-buffers ()
  "Kill all open *Emacs Evaluation* buffers."
  (interactive)
  (mapc (lambda (buf)
          (let ((name (buffer-name buf)))
            (when (string-match-p "^[*]Elisp Evaluation[*]" name)
              (kill-buffer buf))))
        (buffer-list)))

(defun concept-kill-all-shell-command-buffers ()
  "Kill all open *Shell Command* buffers."
  (interactive)
  (mapc (lambda (buf)
          (let ((name (buffer-name buf)))
            (when (string-match-p "^[*]Shell Command[*]" name)
              (kill-buffer buf))))
        (buffer-list)))

(defun concept-eval-elisp (string &optional side-effects)
  "Evaluate an Emacs Lisp STRING in a new dedicated buffer."
  (let* ((origin (current-buffer))
         (origin-name (buffer-name origin))
         (dir default-directory)
         (lexical lexical-binding)
         (lex (if lexical-binding "lexical" "dynamic")))
    (if side-effects
        (with-current-buffer origin
          (eval (read string) lexical-binding))
      (let* ((hash (sha1 (concat string origin-name dir lex)))
             (buf-name (format "*Elisp Evaluation*<%s>" (substring hash 0 6)))
             (buf-new-p (not (bufferp (get-buffer buf-name))))
             (buffer (get-buffer-create buf-name)))
        (when buf-new-p
          (let ((messages '())
                (output-buffer (generate-new-buffer " *Elisp Standard Output*"))
                form
                pretty-code
                result)
            (setq form (read string))
            (setq pretty-code
                  (let ((pp-fill t)
                        (fill-column 30))
                    (pp-to-string form)))
            (when (not pretty-code)
              (user-error "No valid code passed to function!"))
            (unwind-protect
                (with-current-buffer buffer
                  (insert "# Lisp Computation\n\n"
                          "Metadata:\n\n"
                          "```\n"
                          "EmacsVersion: " emacs-version
                          "\nRunDate: "
                          (format-time-string "%Y-%m-%d %H:%M:%S" (current-time))
                          "\nHash: " hash
                          "\nBuffer: " origin-name
                          "\nDirectory: " dir
                          "\nBinding: " lex
                          "\n```\n\n"
                          "## Input\n\n"
                          "Code:\n\n"
                          "```elisp\n"
                          pretty-code
                          "```"
                          "\n\n## Output\n\n")
                  (let ((original-message (symbol-function 'message)))
                    (unwind-protect
                        (progn
                          (fset 'message
                                (lambda (format-string &rest arguments)
                                  (let ((text (apply #'format
                                                     format-string
                                                     arguments)))
                                    (setq messages
                                          (append messages (list text))))))
                          (let ((standard-output output-buffer))
                            (condition-case err
                                (progn
                                  (let ((default-directory dir))
                                    (setq result
                                          (with-current-buffer origin
                                            (eval (read string) lexical))))
                                  (insert "Returns:\n\n"
                                          "```\n"
                                          (prin1-to-string result)
                                          "\n```\n"))
                              (error
                               (insert "Returns:\n\n"
                                       (format "Error: %S" err))))))
                      (fset 'message original-message)))
                  (when (> (buffer-size output-buffer) 0)
                    (insert "\n\nOutput:\n\n"
                            "```text\n"
                            (with-current-buffer output-buffer
                              (buffer-substring-no-properties
                               (point-min)
                               (point-max)))
                            "```\n")))
              (setq messages
                    (seq-filter (lambda (x) (not (string-empty-p x))) messages))
              (when (< 0 (length messages))
                (with-current-buffer buffer
                  (insert "\nMessages:\n\n" "```text\n")
                  (dolist (message messages)
                    (insert (string-trim message) "\n"))
                  (insert "```\n")))
              (when (buffer-live-p output-buffer)
                (kill-buffer output-buffer)))))
      (switch-to-buffer buffer)
      (goto-char (point-min))
      (special-mode)))))

(defun concept-resource-block-keys ()
  "Return a list of all keys in the current resource block."
  (save-excursion
    (when (concept-in-resource-block)
      (concept-goto-current-resource)
      (concept-get-resource-block-attributes))))

(defun concept-goto-key-in-resource-block (key)
  "Navigate to the attribute group line with keyword KEY.
This depends on `concept-resource-block-keys' being in the same order as
they are inside the block."
  (when (and (concept-in-resource-block)
             (let ((keys (concept-resource-block-keys)))
               (when (member key keys)
                 (let ((pos (seq-position keys key)))
                   (concept-goto-current-resource)
                   (dotimes (i (1+ pos))
                     (concept-goto-next-attribute-boundary)
                     (end-of-line))))))))

(defvar concept-last-shell-command-hash
  nil
  "6-digit shell command string hash code.")

(defun concept-shell-command-compilation-buffer-name-function (mode)
  "Name the shell command with part of its hash."
  (format "*Shell Command*<%s>" concept-last-shell-command-hash))

(defun concept-shell-compilation-with-color ()
  (ansi-color-apply-on-region
   compilation-filter-start
   (point-max)))

(defvar concept-compilation-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "w") #'concept-copy-current-buffer-name)
    map))

(define-minor-mode concept-compilation-mode
  "Add features to compilation mode tailored for the needs of concept mapping."
  :lighter "CONCOMP"
  :keymap concept-compilation-mode-map
  (if concept-compilation-mode
      (add-hook 'compilation-filter-hook
                #'concept-shell-compilation-with-color
                nil t)
    (remove-hook
     'compilation-filter-hook
     #'concept-shell-compilation-with-color
     t)))

(defun concept-shell-command (string &optional expect-prompt)
  "Run shell command found in STRING with compilation-mode.
When EXPECT-PROMPT is not nil, place into comint mode."
  (let ((compilation-buffer-name-function
         'concept-shell-command-compilation-buffer-name-function)
        (concept-last-shell-command-hash
         (substring (sha1 string) 0 6)))
    (let ((buf (concept-shell-command-compilation-buffer-name-function "shell"))
          (compilation-mode-hook
           (cons #'concept-compilation-mode compilation-mode-hook))
          (compilation-filter-hook
           (cons #'concept-shell-compilation-with-color compilation-filter-hook)))
      (if (bufferp (get-buffer buf))
          (switch-to-buffer buf)
        (if expect-prompt
            (compile string t)
          (compile string))))))

(defun concept-follow-man (page)
  "Follow to the man page synchronously."
  (let ((Man-notify-method 'pushy)
        (Man-prefer-synchronous-call t))
    (let* ((buf (man-follow page)))
      buf)))

(defun concept-dictionary-search (string)
  "Make a dictionary search and open it's buffer.
Whether this works depends on if the dictionary.el package is installed."
  (if (package-installed-p 'dictionary)
      (and (dictionary-search string)
           (delete-other-windows))
    (message "The dictionary.el interface to rfc2229 dictionaries is not yet installed. Run (package-install 'dictionary) to install it!")))

(defun concept-follow-dwim ()
  "Follow the link if it recognizes the attribute group keyword and the file type.
If the keyword is `file' but the file is not one of the recognized types
that can be opened from Emacs, then try and `mailcap-view-file' to open
an external file viewer. It is recommended to configure these via
modifying `mailcap-user-mime-data'."
  (interactive)
  (cond ((and (concept-on-exposition-line)
              (string= "info" (concept-exposition-parent-key)))
         (save-excursion
           (beginning-of-line)
           (re-search-forward "[^| ]" (line-end-position) t)
           (concept-info-follow)))
        ((and (concept-on-exposition-line)
              (string= "man" (concept-exposition-parent-key)))
         (save-excursion
           (beginning-of-line)
           (re-search-forward "[^| ]" (line-end-position) t)
           (concept-follow-man
            (concept-get-expository-data))))
        ((and (concept-on-exposition-line)
              (string= "file-path" (concept-exposition-parent-key)))
         (save-excursion
           (beginning-of-line)
           (re-search-forward "[^| ]" (line-end-position) t)
           (dired
            (concept-get-expository-data))))
        ((and (concept-on-exposition-line)
              (string= "line" (concept-exposition-parent-key)))
         (let ((keys (concept-resource-block-keys))
               (value (concept-get-expository-data)))
           (cond ((member "man" keys)
                  (concept-goto-key-in-resource-block "man")
                  (forward-line)
                  (let ((mbuf (concept-follow-dwim)))
                    (sit-for 0.1)
                    (when (buffer-live-p mbuf)
                      (with-current-buffer mbuf
                        (goto-line (string-to-number value))))))
                 ((and (member "emacs-package" keys)
                       (member "file-name" keys))
                  (let ((line (concept-get-expository-data)))
                    (concept-goto-key-in-resource-block "file-name")
                    (forward-line)
                    (let ((fbuf (concept-follow-dwim)))
                      (when (buffer-live-p fbuf)
                        (with-current-buffer fbuf
                          (goto-line (string-to-number line))))))))))
        ((and (concept-on-exposition-line)
              (or (string= "pdf-page" (concept-exposition-parent-key))
                  (string= "page"     (concept-exposition-parent-key))))
         (let ((keys (concept-resource-block-keys))
               (value (concept-get-expository-data)))
           (cond ((member "file" keys)
                  (concept-goto-key-in-resource-block "file")
                  (forward-line)
                  (when (concept--is-pdf (concept-get-expository-data))
                    (let ((fbuf (concept-follow-dwim)))
                      (sit-for 0.1)
                      (when (buffer-live-p fbuf)
                        (with-current-buffer fbuf
                          (pdf-view-goto-page (string-to-number value))))))))))
        ((and (concept-on-exposition-line)
              (string= "file-name" (concept-exposition-parent-key)))
         (let ((keys (concept-resource-block-keys))
               (value (concept-get-expository-data)))
           (when (member "emacs-package" keys)
             (save-excursion
               (concept-goto-key-in-resource-block "emacs-package")
               (forward-line)
               (let* ((pkg (concept-get-expository-data))
                      (pkg-file (concat (file-name-directory (locate-library pkg)) value)))
                 (when (and (or (package-installed-p (intern (file-name-nondirectory pkg)))
                                (locate-library pkg))
                            (file-exists-p pkg-file))
                   (find-file pkg-file)))))))
        ((and (concept-on-exposition-line)
              (string= "search-phrase" (concept-exposition-parent-key)))
         (let ((keys (concept-resource-block-keys))
               (value (concept-get-expository-data)))
           (cond ((member "file" keys)
                  (concept-goto-key-in-resource-block "file")
                  (forward-line)
                  (cond ((not (concept--is-file-binary-p (concept-get-expository-data)))
                         (let ((fbuf (concept-follow-dwim)))
                           (when (buffer-live-p fbuf)
                             (with-current-buffer fbuf
                               (goto-char (point-min))
                               (occur value nil)))))
                        ((concept--is-pdf (concept-get-expository-data))
                         (let ((pbuf (concept-follow-dwim)))
                           (sit-for 0.1)
                           (when (buffer-live-p pbuf)
                             (with-current-buffer pbuf
                               (pdf-occur value)))))))
                 ((member "man" keys)
                  (concept-goto-key-in-resource-block "man")
                  (forward-line)
                  (let ((mbuf (concept-follow-dwim)))
                    (when (buffer-live-p mbuf)
                      (with-current-buffer mbuf
                        (occur value)))))
                 ((member "url" keys)
                  (save-excursion
                    (concept-goto-key-in-resource-block "url")
                    (forward-line)
                    (re-search-forward "[^| ]" (line-end-position) t)
                    (let ((wbuf (concept-follow-dwim)))
                      (sit-for 0.1)
                      (when (buffer-live-p wbuf)
                        (with-current-buffer wbuf
                          (occur value))))))
                 ((and (member "emacs-package" keys)
                       (member "file-name" keys))
                  (concept-goto-key-in-resource-block "file-name")
                  (forward-line)
                  (let ((fbuf (concept-follow-dwim)))
                    (when (buffer-live-p fbuf)
                      (with-current-buffer fbuf
                        (occur value)))))
                 ((member "directory" keys)
                  (let ((dir (save-excursion
                               (concept-goto-key-in-resource-block "directory")
                               (forward-line)
                               (file-name-directory (concept-current-exposition)))))
                    (consult-grep dir value)))
                 ((member "info" keys)
                  (concept-goto-key-in-resource-block "info")
                  (forward-line)
                  (concept-follow-dwim)
                  (with-current-buffer "*info*"
                    (beginning-of-buffer)
                    (occur value))))))
        ((and (concept-on-exposition-line)
              (string= "point" (concept-exposition-parent-key)))
         (let ((keys (concept-resource-block-keys))
               (value (concept-get-expository-data)))
           (cond ((member "file" keys)
                  (concept-goto-key-in-resource-block "file")
                  (forward-line)
                  (cond ((not (concept--is-file-binary-p (concept-get-expository-data)))
                         (let ((fbuf (concept-follow-dwim)))
                           (when (buffer-live-p fbuf)
                             (with-current-buffer fbuf
                               (goto-char (string-to-number value))))))))
                 ((member "man" keys)
                  (concept-goto-key-in-resource-block "man")
                  (forward-line)
                  (let ((mbuf (concept-follow-dwim)))
                    (when (buffer-live-p mbuf)
                      (with-current-buffer mbuf
                        (goto-char (string-to-number value))))))
                 ((and (member "emacs-package" keys)
                       (member "file-name" keys))
                  (concept-goto-key-in-resource-block "file-name")
                  (forward-line)
                  (let ((fbuf (concept-follow-dwim)))
                    (when (buffer-live-p fbuf)
                      (with-current-buffer fbuf
                        (goto-char (string-to-number value))))))
                 ((member "info" keys)
                  (concept-goto-key-in-resource-block "info")
                  (forward-line)
                  (concept-follow-dwim)
                  (with-current-buffer "*info*"
                    (beginning-of-buffer)
                    (goto-char (string-to-number value)))))))
        ((and (concept-on-exposition-line)
              (string= "definition" (concept-exposition-parent-key)))
         (concept-dictionary-search (concept-current-exposition)))
        ((and (concept-on-exposition-line)
              (string= "url" (concept-exposition-parent-key)))
         (save-excursion
           (beginning-of-line)
           (re-search-forward "[^| ]" (line-end-position) t)
           (let ((browse-url-browser-function 'concept-eww-browse-url))
             (browse-url-at-point))))
        ((and (concept-on-exposition-line)
              (string= "emacs-package" (concept-exposition-parent-key)))
         (save-excursion
           (beginning-of-line)
           (re-search-forward "[^| ]" (line-end-position) t)
           (concept-describe-package-follow (thing-at-point 'sexp t))))
        ((and (concept-on-exposition-line)
              (or (string= "M-x" (concept-exposition-parent-key))
                  (string= "emacs-command" (concept-exposition-parent-key))))
         (save-excursion
           (beginning-of-line)
           (re-search-forward "[^| ]" (line-end-position) t)
           (call-interactively (intern (thing-at-point 'sexp t)))))
        ((and (concept-on-exposition-line)
              (string= "emacs-buffer" (concept-exposition-parent-key)))
         (save-excursion
           (beginning-of-line)
           (re-search-forward "[^| ]" (line-end-position) t)
           (let ((buf-id (concept-get-expository-data)))
             (if (member buf-id (mapcar #'buffer-name (buffer-list)))
                 (switch-to-buffer buf-id)
               (progn
                 (message "An exact match for %s could not be found. This is the closest match!" buf-id)
                 (concept-switch-to-buffer-with-longest-common-substring buf-id))))))
        ((and (concept-on-exposition-line)
              (string= "emacs-symbol" (concept-exposition-parent-key)))
         (save-excursion
           (beginning-of-line)
           (re-search-forward "[^| ]" (line-end-position) t)
           (concept-describe-symbol-follow (thing-at-point 'sexp t))))
        ((and (concept-on-exposition-line)
              (or (string= "emacs-keybinding" (concept-exposition-parent-key))
                  (string= "kbd" (concept-exposition-parent-key))))
         (save-excursion
           (beginning-of-line)
           (re-search-forward "[^| ]" (line-end-position) t)
           (concept-describe-keybinding-follow (concept-get-expository-data))))
        ((and (concept-on-exposition-line)
              (or (string= "shell-command" (concept-exposition-parent-key))
                  (string= "shell" (concept-exposition-parent-key))))
         (save-excursion
           (beginning-of-line)
           (re-search-forward "[^| ]" (line-end-position) t)
           (let ((default-directory
                  (file-name-as-directory
                   (or
                    (and (member "directory" (concept-resource-block-keys))
                         (let ((proposed-directory
                                (save-excursion
                                  (concept-goto-key-in-resource-block "directory")
                                  (forward-line)
                                  (concept-get-expository-data))))
                           (when (file-exists-p proposed-directory)
                             (expand-file-name proposed-directory))))
                    default-directory))))
             (concept-shell-command
              (concept-get-expository-data)
              (member "prompt" (concept-resource-block-keys))))))
        ((and (concept-on-exposition-line)
              (or (string= "emacs-lisp" (concept-exposition-parent-key))
                  (string= "lisp" (concept-exposition-parent-key))))
         (save-excursion
           (beginning-of-line)
           (re-search-forward "[^| ]" (line-end-position) t)
           (let ((code
                  (concept-get-expository-data))
                  (default-directory
                  (or
                   (and (member "directory" (concept-resource-block-keys))
                        (save-excursion
                          (concept-goto-key-in-resource-block "directory")
                          (forward-line)
                          (expand-file-name (concept-get-expository-data))))
                   default-directory))
                  (side-effects
                   (member "side-effects" (concept-resource-block-keys)))
                  (target-buffer
                   (if (member "emacs-buffer" (concept-resource-block-keys))
                       (concept--closest-buffer-by-longest-common-substring
                        (save-excursion
                          (concept-goto-key-in-resource-block "emacs-buffer")
                          (forward-line)
                          (concept-get-expository-data)))
                     (current-buffer))))
             (with-current-buffer target-buffer
               (concept-eval-elisp code side-effects)))))
        ((and (concept-on-exposition-line)
              (string= "file" (concept-exposition-parent-key)))
         (save-excursion
           (beginning-of-line)
           (re-search-forward "[^| ]" (line-end-position) t)
           (let ((data (concept-get-expository-data)))
             (if (or (not (concept--is-file-binary-p data))
                     (concept--is-image-file data)
                     (concept--is-pdf data))
                 (concept-find-file)
               (mailcap-view-file data)))))))

(defun concept-copy-current-file-path ()
  "Copy the current buffer's file path to the kill ring."
  (interactive)
  (if-let ((file (buffer-file-name)))
      (progn
        (kill-new (expand-file-name file))
        (when (called-interactively-p)
          (message "Copied Path: %s" file)))
    (user-error "Current buffer is not visiting a file")))

(defun concept-copy-current-buffer-name ()
  "Copy the current buffer's name to the kill ring."
  (interactive)
  (let ((buf (buffer-name)))
    (progn
      (kill-new buf)
      (when (called-interactively-p)
        (message "Copied buffer named %s to the kill ring" buf)))))

(defun concept-insert-delimited--helper (arg separator)
  "This handles the internal logic."
  (when (number-or-marker-p arg)
    (setq arg (number-to-string arg)))
  (when (string-match-p separator arg)
    (error "Separator found in data string!"))
  (insert arg))

(defun concept-insert-delimited (separator &rest args)
  "Insert text separated by SEPARATOR."
  (dolist (arg (butlast args))
    (concept-insert-delimited--helper arg separator)
    (insert separator))
  (concept-insert-delimited--helper (car (last args)) separator)
  (insert "\n"))

(defun concept-map-has-more-data-concepts ()
  "Test whether the buffer has more data concepts in it."
  (save-excursion
    (end-of-line)
    (re-search-forward concept-object-line-regexp nil t)))

(defun concept-map-has-more-exposition-lines ()
  "Test whether the buffer has more exposition lines in it."
  (save-excursion
    (end-of-line)
    (re-search-forward "^| +[[{‘]" nil t)))

(defun concept-map-has-more-data-concepts-or-exposition-lines ()
  "Check whether there are more lines to consume."
  (or (not (concept-on-last-line-in-block-p))
      (concept-map-has-more-resources)
      (concept-map-has-more-concept-blocks)))

(defun concept-current-focus-position ()
  "Return the line number for the current focus line."
  (save-excursion
    (concept-goto-current-focus)
    (line-number-at-pos (point))))

(defun concept-current-resource-position ()
  "Return the line number for the current resource line."
  (when (concept-in-resource-block)
    (save-excursion
      (concept-goto-current-resource)
      (line-number-at-pos (point)))))

(defun concept-on-last-line-in-block-p ()
  "Test whether the next line enters a new block.
In practice this means that the next line is either a focus line or a
resource line."
  (save-excursion
    (ignore-errors (forward-line))
    (or (concept-on-focus-line)
        (concept-on-resource-line)
        (progn (end-of-line) (eobp)))))

(defun concept-goto-next-data-concept-or-exposition-line ()
  "Move forward to the next data concept or exposition line."
  (interactive)
  (if (concept-in-relationship-block)
      (cond ((not (concept-on-last-line-in-block-p))
             (concept-goto-next-data-concept))
            ((and (concept-on-last-line-in-block-p)
                  (concept-idea-has-resources))
             (concept-goto-next-exposition))
            ((and (concept-on-last-line-in-block-p)
                  (not (concept-idea-has-resources)))
             (concept-goto-next-data-concept))
            (t (error "This relationship block condition should not have been reached!")))
    (cond ((or (concept-on-resource-line)
               (concept-on-attribute-line))
           (concept-goto-next-exposition))
          ((and (concept-on-exposition-line)
                (not (concept-on-last-line-in-block-p)))
           (concept-goto-next-exposition))
        ((and (concept-on-last-line-in-block-p)
              (concept-idea-has-more-resources))
         (concept-goto-next-exposition))
        ((and (concept-on-last-line-in-block-p)
              (not (concept-idea-has-more-resources)))
         (concept-goto-next-data-concept))
        (t (error "This resource block condition should not have been reached!")))))

(defvar concept-focus-editing-history nil
  "History for the concept map editing tools.")

(defvar concept-resource-editing-history nil
  "History for the concept map editing tools.")

(defvar concept-attribute-editing-history nil
  "History for the concept map editing tools.")

(defvar concept-relationship-editing-history nil
  "History for the concept map editing tools.")

(defvar concept-concept-editing-history nil
  "History for the concept map editing tools.")

(defvar concept--edit-group-restriction-failed-msg
    "Replace failed to pass group name restrictions"
  "Editing in the buffur failed due to group restrictions.")

(defvar concept--edit-is-the-same-msg
  "No changes found during edit!"
  "No changes were found. Let the user know.")

(defun concept-edit-focus ()
  "Edit the current focus concept and replace it with a new one if valid."
  (interactive)
  (save-excursion
    (concept-goto-current-focus)
    (let* ((old-text (concept-current-focus))
           (new-text (string-trim (read-string "Subject: " old-text 'concept-focus-editing-history old-text)))
           (focus-regexp concept-group-name-regexp))
      (cond ((equal old-text new-text)
             (message concept--edit-is-the-same-msg))
            ((string-match-p focus-regexp new-text)
             (beginning-of-line)
             (re-search-forward "[^~ ]+" (line-end-position) t)
             (kill-line)
             (insert new-text))
            (t (message concept--edit-group-restriction-failed-msg))))))

(defun concept-edit-resource ()
  "Edit the current resource block and replace it with a new one if valid."
  (interactive)
  (when (concept-in-resource-block)
    (save-excursion
      (concept-goto-current-resource)
      (let* ((old-text (concept-current-resource))
             (new-text (string-trim (read-string "Resource: " old-text 'concept-resource-editing-history old-text)))
             (resource-regexp concept-group-name-regexp))
        (cond ((equal old-text new-text)
               (message concept--edit-is-the-same-msg))
              ((string-match-p resource-regexp new-text)
               (beginning-of-line)
               (re-search-forward "[^@ ]+" (line-end-position) t)
               (kill-line)
               (insert new-text))
              (t (message concept--edit-group-restriction-failed-msg)))))))

(defun concept-edit-data-concept ()
  "Edit the current resource block and replace it with a new one if valid."
  (interactive)
  (when (concept-on-data-concept-line)
    (let* ((old-text (concept-current-concept))
           (new-text (string-trim (read-string "Object: " old-text 'concept-concept-editing-history old-text)))
           (concept-regexp concept-group-name-regexp))
      (cond ((equal old-text new-text)
             (message concept--edit-is-the-same-msg))
            ((string-match-p concept-regexp new-text)
             (beginning-of-line)
             (re-search-forward "| +" (line-end-position) t)
             (kill-line)
             (insert new-text))
            (t (message concept--edit-group-restriction-failed-msg))))))

(defun concept-edit-relationship ()
  "Edit the current resource block and replace it with a new one if valid."
  (interactive)
  (when (and (concept-in-relationship-block)
             (not (concept-on-focus-line)))
    (when (concept-on-data-concept-line)
      (concept-goto-last-relationship))
    (save-excursion
      (let* ((old-text (concept-current-relationship))
             (new-text (string-trim (read-string "Object: " old-text 'concept-relationship-editing-history old-text)))
             (relationship-regexp concept-group-name-regexp))
        (cond ((equal old-text new-text)
               (message concept--edit-is-the-same-msg))
              ((string-match-p relationship-regexp new-text)
               (beginning-of-line)
               (re-search-forward "^| +:" (line-end-position) t)
               (kill-line)
               (insert new-text))
              (t (message concept--edit-group-restriction-failed-msg)))))))

(defun concept-edit-keyword ()
  "Edit the current resource block and replace it with a new one if valid."
  (interactive)
  (when (and (concept-in-resource-block)
             (not (concept-on-resource-line)))
    (when (concept-on-exposition-line)
      (concept-goto-last-attribute))
    (save-excursion
      (let* ((old-text (concept-current-attribute))
             (new-text (string-trim (read-string "Keyword: " old-text 'concept-attribute-editing-history old-text)))
             (keyword-regexp concept-group-name-regexp))
        (cond ((and (not (equal old-text new-text))
                    (string-match-p keyword-regexp new-text))
               (beginning-of-line)
               (re-search-forward "^| +" (line-end-position) t)
               (kill-line)
               (insert new-text ":"))
              (t (message concept--edit-group-restriction-failed-msg)))))))

(defun concept-pick-needed-data-delimiters (text)
  "Pick the simplest pair of delimiters needed to store the string in a concept map."
  (cond ((not (string-match-p "[{}]" text))
         "{}")
        ((not (or (string-match-p "\\]" text)
                  (string-match-p "\\[" text)))
         "[]")
        (t "‘’")))

(defvar concept-editing-exposition-history nil
  "History for the concept map editing tools relevant to expository data.")

(defun concept-edit-exposition ()
  "Edit the current piece of expository data and replace the previous entry."
  (interactive)
  (when (and (concept-in-resource-block)
             (concept-on-exposition-line))
    (save-excursion
      (let* ((old-text (concept-current-exposition))
             (new-text (string-trim (read-string "Data: " old-text 'concept-editing-exposition-history old-text)))
             (needed-delims (concept-pick-needed-data-delimiters new-text)))
        (when (not (equal old-text new-text))
          (beginning-of-line)
          (re-search-forward "^| +" (line-end-position) t)
          (kill-line)
          (insert needed-delims)
          (search-forward (substring needed-delims 0 1))
          (insert new-text))))))

(defun concept-edit-line-dwim ()
  "Edit the line at point in the concept map. However that is done!"
  (interactive)
  (cond ((concept-on-focus-line)
         (concept-edit-focus))
        ((concept-on-resource-line)
         (concept-edit-resource))
        ((concept-on-data-concept-line)
         (concept-edit-data-concept))
        ((concept-on-exposition-line)
         (concept-edit-exposition))
        ((concept-on-relationship-line)
         (concept-edit-relationship))
        ((concept-on-attribute-line)
         (concept-edit-keyword))))

(defun concept-edit-group-dwim ()
  "Edit the parent group name for the piece of data at point."
  (interactive)
  (cond ((concept-on-data-concept-line)
         (concept-edit-relationship))
        ((concept-on-exposition-line)
         (concept-edit-keyword))
        ((concept-on-focus-line)
         (concept-edit-focus))
        ((concept-on-resource-line)
         (concept-edit-resource))
        ((concept-on-attribute-line)
         (forward-line)
         (beginning-of-line)
         (re-search-forward "[^| ]" (line-end-position) t))))

(defun concept-edit-dwim (arg)
  "Edit the thing I want to edit relevant to the current point."
  (interactive "P")
  (if (null arg)
      (concept-edit-line-dwim)
    (concept-edit-group-dwim)))

(defun concept-map-export-to-table (&optional sep)
  "Convert a concept map into a TSV table.
This table is fairly convenient to work with from `igraph'."
  (interactive)
  (unless sep (setq sep "\t"))
  (when (derived-mode-p 'concept-mode)
    (let ((cbuf (current-buffer))
          (nbuf (get-buffer-create "*concept-map-export*")))
      (with-current-buffer nbuf
        (erase-buffer)
        (concept-insert-delimited
         sep "idea" "block" "type" "parent" "child" "link"))
      (with-current-buffer cbuf
        (goto-char (point-min))
        (while (concept-map-has-more-data-concepts-or-exposition-lines)
          (concept-goto-next-data-concept-or-exposition-line)
          (cond ((concept-on-concept-line)
                 (let ((idea          (concept-current-focus-position))
                       (type         "relationship")
                       (block        (concept-current-focus-position))
                       (subject     (concept-current-focus))
                       (relationship (concept-current-relationship))
                       (object       (concept-current-concept)))
                   (with-current-buffer nbuf
                     (concept-insert-delimited
                      sep idea block type subject object relationship))))
                ((concept-on-exposition-line)
                 (let ((idea           (concept-current-focus-position))
                       (type           "resource")
                       (block          (concept-current-resource-position))
                       (resource       (concept-current-resource-name))
                       (keyword        (concept-current-attribute))
                       (data           (concept-get-expository-data)))
                   (with-current-buffer nbuf
                     (concept-insert-delimited
                      sep idea block type resource data keyword))))
                (t (error "This should never get triggered!"))))
        (pop-to-buffer nbuf)))))

(defun concept-table-get--helper (field)
  (when (and (string= (buffer-name) "*concept-map-export*")
             (< 1 (line-number-at-pos (point))))
    (let ((line (concept-current-line)))
      (with-temp-buffer
        (insert line)
        (shell-command-on-region
         (point-min)
         (point-max)
         (format "cut -f%d" field)
         nil
         t)
        (string-trim-right ; TODO: probably don't need this anymore!
         (buffer-string))))))

(defun concept-table-get-parent ()
  "Get parent concept name on TSV line."
  (concept-table-get--helper 4))

(defun concept-table-get-child ()
  "Get parent concept name on TSV line."
  (concept-table-get--helper 5))

(defun concept-table-get-link ()
  "Get parent concept name on TSV line."
  (concept-table-get--helper 6))

(defvar concept-gephi-template
  "<gexf xmlns=\"http://gexf.net/1.3\"
       xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"
       xsi:schemaLocation=\"http://gexf.net/1.3
                           http://gexf.net/1.3/gexf.xsd\"
       version=\"1.3\">
  <meta lastmodifieddate=\"2009-03-20\">
    <creator>Gephi.org</creator>
    <description>A sample GEXF file</description>
  </meta>
  <graph mode=\"static\" defaultedgetype=\"directed\">
    <nodes>
    NNNN
    </nodes>
    <edges>
    RRRR
    </edges>
  </graph>
</gexf>
"
  "Gephi GEXF template")

(defun concept-table-export-to-gexp ()
  "Export the relationship block data in the exported TSV table to GEXP."
  (interactive)
  (when (string= (buffer-name) "*concept-map-export*")
    (goto-char (point-min))
    (forward-line)
    (keep-lines "	relationship	" (line-beginning-position) (point-max))
    (let* ((n 0)
           (e 0)
           (tbuf  (buffer-name))
           (gbuf (get-buffer-create "*relationship-export-gexf*"))
           (nodes (make-hash-table :test #'equal))
           (make-node
            (lambda (id lbl)
              ;; TODO: Would be nice to directly reference the lexical gbuf
              (let ((gbuf (get-buffer "*relationship-export-gexf*")))
                (with-current-buffer gbuf
                  (goto-char (point-min))
                  (search-forward "NNNN")
                  (beginning-of-line)
                  (open-line 1)
                  (insert "    ")
                  (insert "<node id=\"" (number-to-string id)
                          "\" label=\"" (string-replace "-" " " (xml-escape-string lbl))  "\" />")))))
           (make-edge
            (lambda (src tgt lbl)
              ;; TODO: Would be nice to directly reference the lexical gbuf
              (let ((gbuf (get-buffer "*relationship-export-gexf*")))
                (with-current-buffer gbuf
                  (goto-char (point-min))
                  (search-forward "RRRR")
                  (beginning-of-line)
                  (open-line 1)
                  (insert "    ")
                  (insert "<edge source=\"" (number-to-string src)
                          "\" target=\""    (number-to-string tgt)
                          "\" label=\""     (xml-escape-string lbl)
                          "\" />"))))))
      (with-current-buffer gbuf
        (erase-buffer)
        (insert concept-gephi-template))
      (while (not (eobp))
        (let ((parent (concept-table-get-parent))
              (child  (concept-table-get-child))
              (link   (concept-table-get-link)))
          (when (not (map-contains-key nodes parent))
            (setq n (1+ n))
            (puthash parent n nodes)
            (funcall make-node n parent))
          (when (not (map-contains-key nodes child))
            (setq n (1+ n))
            (puthash child n nodes)
            (funcall make-node n child))
          (let ((src (gethash parent nodes))
                (tgt (gethash child  nodes)))
            (funcall make-edge src tgt link)))
        (forward-line))
      (with-current-buffer gbuf
        (goto-char (point-min))
        (search-forward "NNNN")
        (kill-whole-line)
        (search-forward "RRRR")
        (kill-whole-line)
        (goto-char (point-min)))
      (pop-to-buffer gbuf))))

(defun concept-map-check-parse ()
  "Test whether the current concept map parses successfully.
If it doesn't parse, move the point to where the first failure is."
  (interactive)
  (condition-case error-signal
      (save-excursion
        (goto-char (point-min))
        (and (peg-parse
              (concept-map
               (and (bob) (+ idea) (* whitespace) (eob)))
              (whitespace (or " " "\n" "\t"))
              (idea
               (and subject
                    (+ (and relationship-group (+ object)))
                    (* (and resource-group
                            (+ (and attribute-group
                                    (+ (and attribute))))))))
              (subject
               (and subject-intro group-name ending))
              (group-name
               (substring (+ (not disallowed) (any))))
              (disallowed (or " " ":" ";" "\t" "\n"))
              (relationship-group
               (and data-intro ":" relationship ending))
              (relationship group-name)
              (data-intro     (and (bol) "|" (+ " ")))
              (resource-intro (and (bol) "@" (+ " ")))
              (subject-intro  (and (bol) "~" (+ " ")))
              (ending (and (* " ") (or "\n" (eob))))
              (object
               (and data-intro concept ending))
              (resource-group
               (and resource-intro resource ending))
              (resource group-name)
              (concept  group-name)
              (keyword  group-name)
              (attribute-group (and data-intro keyword ":" ending))
              (attribute
               (and data-intro data ending))
              (data (or braced-data bracketed-data unicode-data))
              (braced-data
               (and "{" braced-contents "}"))
              (braced-contents
               (substring (* (not (or "{" "}" "\n")) (any))))
              (bracketed-data
               (and "[" bracketed-contents "]"))
              (bracketed-contents
               (substring (* (not (or "[" "]" "\n")) (any))))
              (unicode-data
               (and "‘" unicode-contents "’"))
              (unicode-contents
               (substring (* (not (or "‘" "’" "\n")) (any)))))
             (message "Successful Parse!")))
    (peg-search-failed
     (goto-char (nth 1 error-signal))
     (user-error "Parse failed at point!"))))

(defvar-local concept-map--network-update-timer nil
  "Update the concept map network after buffer modifications and a bit of inactivity.")

(defun concept-map--schedule-network-update (&rest _args)
  "Schedule a network update after a period of user inactivity."
  (when (timerp concept-map--network-update-timer)
    (cancel-timer concept-map--network-update-timer)
    (concept-map--debug "Canceled previous timer in %s" (buffer-name))
    (setq concept-map--network-update-timer
      (run-with-idle-timer
       5 nil
       #'concept-map--run-scheduled-network-update
       (current-buffer)))
    (concept-map--debug
     "Scheduled update for %s; modified=%S"
     (buffer-name)
     (buffer-modified-p))))

(defun concept-map--run-scheduled-network-update (buffer)
  "Update BUFFER's concept map network.
This variable is stored in `concept-map-network-graph'."
  (if (not (buffer-live-p buffer))
      (concept-map--debug "Skipped update: buffer no longer exists")
    (with-current-buffer buffer
      (setq concept-map--network-update-timer nil)
      (when (derived-mode-p 'concept-mode)
         (concept-map--debug
          "Running concept-map-update-network in %s"
          (buffer-name))
        (concept-map-update-network)))))

(defun concept-mode-setup-network-updating ()
  "Enable automatic network updates for the current buffer."
  (add-hook 'after-change-functions
            #'concept-map--schedule-network-update
            nil
            t))

(defun concept-map--debug (format-string &rest args)
  "Log concept-map update activity."
  (with-current-buffer (get-buffer-create "*concept-map-debug*")
    (goto-char (point-max))
    (insert (format-time-string "[%H:%M:%S] "))
    (insert (apply #'format format-string args))
    (insert "\n")))

(add-hook 'concept-mode-hook
          #'concept-mode-setup-network-updating)

(defvar-local concept-map-network-relationship-regexp
    ".+"
  "Buffer local setting for picking the relationships added to the network
representation of the concept map.")

(defvar-local concept-map-network-graph
    nil
  "Buffer local representation of the concept map as a network.")

(defun concept-map-update-network (&optional relationship-regexp)
  "Extract the concept map network into the SEXP.
Store the resulting data structure in `concept-map-network-graph'.

The form of this data structure is a hash table where the keys are
concepts and the values are list of concepts that are children of the key:

 '((foo . (bar))
   (bar . (baz))
   (baz . ()))
"
  (unless (derived-mode-p 'concept-mode)
    (user-error "This only works inside of a concept-mode buffer holding a valid concept map!"))
  (when (null relationship-regexp)
    (setq relationship-regexp ".+"))
  (save-excursion
    (let ((graph (make-hash-table :test #'equal)))
      (concept--goto-first-heading)
      (concept-goto-next-relationship)
      (while (not (eobp))
        (let ((relationship (concept-get-relationship)))
          (when (string-match-p relationship-regexp relationship)
            (let ((parent (concept-current-focus))
                  (children (concept-get-child-concepts)))
              (puthash parent (delete-dups (append (gethash parent graph) children)) graph))))
        (concept-goto-next-relationship))
      (setq-local concept-map-network-graph graph)
      graph)))

(defun concept-map-network-reachable-p (start goal)
  "Return non-nil if GOAL is reachable from START."
  (let ((graph (or concept-map-network-graph
                   (concept-map-update-network)))
        (visited (make-hash-table :test #'equal))
        (pending (list start)))
    (catch 'found
      (while pending
        (let ((node (pop pending)))
          (unless (gethash node visited)
            (puthash node t visited)
            (when (equal node goal)
              (throw 'found t))
            (dolist (child (gethash node graph))
              (unless (gethash child visited)
                (push child pending))))))
      nil)))

(defun concept-map--network-path (start goal)
  "Return a path from START to GOAL, or nil if GOAL is unreachable."
  (let ((graph (or concept-map-network-graph
                   (concept-map-update-network)))
        (visited (make-hash-table :test #'equal))
        (pending (list (cons start (list start)))))
    (catch 'path-found
      (while pending
        (let* ((entry (pop pending))
               (node (car entry))
               (path (cdr entry)))
          (unless (gethash node visited)
            (puthash node t visited)
            (if (equal node goal)
                (throw 'path-found (reverse path))
              (dolist (child (gethash node graph))
                (unless (gethash child visited)
                  (push (cons child (cons child path))
                        pending))))))
        nil))))

(defun concept-map-find-network-path (start goal)
  "Search for a path from a proposed ANCESTOR to a proposed DESCENDANT.
When a path is found, print it out in the minibuffer and return the list
representation."
  (interactive
   (let* ((concepts (concept-find-all-concepts))
          (start
           (completing-read
            "Starting concept: "
            concepts nil t))
          (remaining (delete start (copy-sequence concepts)))
          (goal
           (completing-read
            "Destination concept: "
            remaining
            nil t)))
     (list start goal)))
     (let ((path (concept-map--network-path start goal)))
       (when (called-interactively-p 'interactive)
         (if path
             (let ((path-string
                    (mapconcat
                     (lambda (node)
                       (format "%s" node))
                     path
                     " -> ")))
               (message "%s" path-string))
           (message "No path from %s to %s found!" start goal)))
       path))

(defun concept--find-cycle-from (node path graph state)
  "Find a cycle reachable from NODE.

PATH is the current DFS path. STATE records nodes as
:visiting or :done. Return a cycle, or nil."
  (let ((node-state (gethash node state)))
    (cond
     ((eq node-state :visiting)
      (let ((cycle-start (member node path)))
        (append cycle-start (list node))))
     ((eq node-state :done)
      nil)
     (t
      (puthash node :visiting state)
      (let ((cycle nil))
        (dolist (child (gethash node graph))
          (unless cycle
            (setq cycle
                  (concept--find-cycle-from
                   child
                   (append path (list child))
                   graph
                   state))))
        (puthash node :done state)
        cycle)))))

(defun concept-map-find-network-cycle ()
  "Return the first directed cycle in the network, or nil.

When called interactively, display the cycle as a string such as:
A -> B -> C -> A"
  (interactive)
  (let ((graph (or concept-map-network-graph
                   (concept-map-update-network)))
        (state (make-hash-table :test #'equal))
        cycle)
    (catch 'cycle-found
      (maphash
       (lambda (node _children)
         (unless (gethash node state)
           (setq cycle
                 (concept--find-cycle-from
                  node
                  (list node)
                  graph
                  state))
           (when cycle
             (throw 'cycle-found cycle))))
       graph))
    (if (called-interactively-p 'interactive)
        (if cycle
            (let ((cycle-string
                   (mapconcat
                    (lambda (node)
                      (format "%s" node))
                    cycle
                    " -> ")))
              (message "%s" cycle-string)
              cycle-string)
          (message "No concept dependency cycles found!")
          nil)
      cycle)))

(defun concept-do-nothing ()
  (interactive)
  (message "Nothing was do because upcasing all the text in a concept map is a bad idea.")
  nil)

(define-key concept-mode-map (kbd "C-x C-u")     #'concept-do-nothing)
(define-key concept-mode-map (kbd "C-M-o")       #'concept-add-new-data)
(define-key concept-mode-map (kbd "M-j")         #'concept-add-new-data)
(define-key concept-mode-map (kbd "M-k")         #'concept-add-data)
(define-key concept-mode-map (kbd "C-o")         #'concept-add-dwim)
(define-key concept-mode-map (kbd "M-o")         #'concept-repeat-dwim)
(define-key concept-mode-map (kbd "M-RET")       #'concept-add-new-data)
(define-key concept-mode-map (kbd "TAB")         #'concept-change-dwim)
(define-key concept-mode-map (kbd "M-TAB")       #'concept-change-dwim)
(define-key concept-mode-map (kbd "M-r")         #'concept-cycle-context)
(define-key concept-mode-map (kbd "C-M-y")       #'concept-repeat-current-block)
(define-key concept-mode-map (kbd "M-.")         #'concept-insert-focus-as-new)
(define-key concept-mode-map (kbd "C-M-.")       #'concept-insert-concept-dwim)
(define-key concept-mode-map (kbd "C-.")         #'concept-insert-last-concept-as-new)
(define-key concept-mode-map (kbd "M-i")         #'concept-insert-include-dwim)
(define-key concept-mode-map (kbd "M-]")         #'concept-slurp-next-concept)
(define-key concept-mode-map (kbd "M-[")         #'concept-barf-current-concept)
(define-key concept-mode-map (kbd "C-M-<down>")  #'concept-goto-next-thing)
(define-key concept-mode-map (kbd "C-M-<up>")    #'concept-goto-last-thing)
(define-key concept-mode-map (kbd "C-<down>")    #'concept-go-one-group-down)
(define-key concept-mode-map (kbd "C-<up>")      #'concept-go-one-group-up)
(define-key concept-mode-map (kbd "M-<down>")    #'concept-exchange-down-dwim)
(define-key concept-mode-map (kbd "M-<up>")      #'concept-exchange-up-dwim)
(define-key concept-mode-map (kbd "C-c f")       #'concept-follow-dwim)
(define-key concept-mode-map (kbd "C-c ~")       #'concept-next-double-heading)
(define-key concept-mode-map (kbd "C-c y r")     #'concept-consult-yank-from-resources)
(define-key concept-mode-map (kbd "C-c y c")     #'concept-consult-yank-from-ideas)
(define-key concept-mode-map (kbd "C-c y i")     #'concept-consult-yank-from-ideas)
(define-key concept-mode-map (kbd "C-c s")       #'concept-consult-search-concept-blocks)
(define-key concept-mode-map (kbd "C-c C-s")     #'concept-consult-search-resource-blocks)
(define-key concept-mode-map (kbd "C-c [")       #'concept-insert-unicode-quote-brackets)
(define-key concept-mode-map (kbd "C-c '")       #'concept-insert-unicode-quote-brackets)
(define-key concept-mode-map (kbd "C-c o")       #'consult-outline)
(define-key concept-mode-map (kbd "C-c i")       #'imenu)
(define-key concept-mode-map (kbd "C-c C-i")     #'consult-imenu)
(define-key concept-mode-map (kbd "C-c C-n")     #'concept-goto-next-dwim)
(define-key concept-mode-map (kbd "C-c C-p")     #'concept-goto-previous-dwim)
(define-key concept-mode-map (kbd "C-c C-e")     #'concept-expand-combinatorial-relationship-block)
(define-key concept-mode-map (kbd "C-c C-= g")   #'concept-set-last-relationship-size-behavior)
(define-key concept-mode-map (kbd "C-c C-= a")   #'concept-set-last-attribute-count-behavior)
(define-key concept-mode-map (kbd "C-c C-= r")   #'concept-set-last-resource-count-behavior)
(define-key concept-mode-map (kbd "C-c C-= c")   #'concept-set-last-size-comparison-behavior)
(define-key concept-mode-map (kbd "C-c M-p")     #'concept-cleanup-map)
(define-key concept-mode-map (kbd "C-c C-v")     #'concept-map-check-parse)
(define-key concept-mode-map (kbd "C-c C-t")     #'concept-map-export-to-table)
(define-key concept-mode-map (kbd "C-c e")       #'concept-edit-dwim)
(define-key concept-mode-map (kbd "M-;")         #'concept-split-dwim)
(define-key concept-mode-map (kbd "C-c M-;")     #'concept-swap-data-with-focus)
(define-key concept-mode-map (kbd "C-M-;")       #'concept-data-split-dwim)
(define-key concept-mode-map (kbd "C-;")         #'concept-isolate-dwim)
(define-key concept-mode-map (kbd "C-c C-a")     #'concept-alphabetic-sort-dwim)
(define-key concept-mode-map (kbd "C-c C-r")     #'concept-reverse-order-dwim)
(define-key concept-mode-map (kbd "C-c M-r")     #'concept-randomize-dwim)
(define-key concept-mode-map (kbd "C-c C-o")     #'concept-canonical-sort-dwim)
(define-key concept-mode-map (kbd "C-c C-d")     #'concept-map-find-network-cycle)
(define-key concept-mode-map (kbd "C-c C-f")     #'concept-map-find-network-path)

(provide 'concept)
;;; concept.el ends here
