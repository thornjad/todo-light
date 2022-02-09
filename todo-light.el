;;; todo-light.el --- highlight TODO and similar keywords  -*- lexical-binding: t -*-
;;
;; Author: Jade Michael Thornton
;; Copyright (c) 2019-2022 Jade Michael Thornton
;; Copyright (C) 2013-2018 Jonas Bernoulli
;; Package-Requires: ((emacs "24") (cl-lib))
;; URL: https://gitlab.com/thornjad/todo-light
;; Version: 1.2.1
;;
;; This file is not part of GNU Emacs.
;;
;; This file is free software; you can redistribute it and/or modify it under
;; the terms of the GNU General Public License, version 3, as published by the
;; Free Software Foundation.
;;
;; This file is distributed in the hope that it will be useful, but WITHOUT ANY
;; WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
;; A PARTICULAR PURPOSE. See the GNU General Public License for more details.
;;
;; For a full copy of the GNU General Public License see
;; <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Highlights TODO and similar keywords in comments and strings.
;;
;; You can either turn on `todo-light-mode' in individual buffers or use the the
;; global variant `global-todo-light-mode'. Note that the option
;; `todo-light-activate-in-modes' controls in what buffers the local mode will be
;; activated if you do the latter. By default it will only be activated in
;; buffers whose major-mode derives from `prog-mode'.
;;
;; This package also provides commands for moving to the next or previous
;; keyword, to invoke `occur' with a regexp that matches all known keywords, and
;; to insert a keyword. If you want to use these commands, then you should bind
;; them in `todo-light-mode-map'
;;
;; todo-light is forked from hl-todo by Jonas Bernoulli to make some needed
;; improvements.

;;; Code:

(eval-when-compile
  (require 'cl-lib))

(defgroup todo-light nil
  "Highlight TODO and similar keywords in comments and strings."
  :group 'font-lock-extra-types)

(defface todo-light
  '((t (:bold t :foreground "#cc9393")))
  "Base face used to highlight TODO and similar keywords.
The faces used to highlight certain keywords are, by default, created by
inheriting this face and using the appropriate color specified using the option
`todo-light-keyword-faces' as foreground color."
  :group 'todo-light)

(defcustom todo-light-activate-in-modes '(prog-mode text-mode)
  "Major-modes in which function `todo-light-mode' should be activated.

Even though `org-mode' indirectly derives from `text-mode' this mode is never
activated in `org-mode' buffers because that mode provides its own TODO keyword
handling."
  :package-version '(todo-light . "2.1.0")
  :group 'todo-light
  :type '(repeat function))

(defcustom todo-light-text-modes '(text-mode)
  "Major-modes that are considered text-modes.

In buffers whose major mode derives from one of the modes listed here TODO
keywords are always highlighted even if they are not located inside a string."
  :package-version '(todo-light . "2.1.0")
  :group 'todo-light
  :type '(repeat function))

(defcustom todo-light-keyword-faces
  '(("TODO" . "#cc9393")
    ("NEXT" . "#dca3a3")
    ("DONT" . "#5f7f5f")
    ("NOTE" . "#5f7f5f")
    ("FAIL" . "#8c5353")
    ("DONE" . "#afd8af")
    ("ASSUMPTION" . "#d0bf8f")
    ("KLUDGE" . "#d0bf8f")
    ("HACK" . "#d0bf8f")
    ("TEMP" . "#d0bf8f")
    ("DEBUG" . "#d0bf8f")
    ("FIXME" . "#cc9393"))
  "Faces used to highlight specific TODO keywords.

Each entry has the form (KEYWORD . COLOR). KEYWORD is used as part of a regular
expression. If (regexp-quote KEYWORD) is not equal to KEYWORD, then it is
ignored by `todo-light-insert-keyword'.

The syntax class of the characters at either end has to be `w' \(which means
word) in `todo-light--syntax-table'. That syntax table derives from
`text-mode-syntax-table' but uses `w' as the class of \"?\".

This package, like most of Emacs, does not use POSIX regexp backtracking. See
info node `(elisp)POSIX Regexp' for why that matters. If you have two keywords
\"TODO-NOW\" and \"TODO\", then they must be specified in that order.
Alternatively you could use \"TODO\\(-NOW\\)?\"."
  :package-version '(todo-light . "3.0.0")
  :group 'todo-light
  :type '(repeat (cons (string :tag "Keyword")
		                   (choice :tag "Face   "
			                   (string :tag "Color")
			                   (sexp :tag "Face")))))

(defcustom todo-light-highlight-punctuation ""
  "String of characters to highlight after keywords.

Each of the characters appearing in this string is highlighted using the same
face as the preceeding keyword when it directly follows the keyword.

Characters whose syntax class is `w' (which means word), including alphanumeric
characters, cannot be used here."
  :package-version '(todo-light . "2.0.0")
  :group 'todo-light
  :type 'string)

(defvar-local todo-light--regexp nil)
(defvar-local todo-light--keywords nil)

(defun todo-light--setup ()
  (let ((bomb (assoc "???" todo-light-keyword-faces)))
    (when bomb
      ;; If the user customized this variable before we started to
      ;; treat the strings as regexps, then the string "???" might
      ;; still be present.  We have to remove it because it results
      ;; in the regexp search taking forever.
      (setq todo-light-keyword-faces (delete bomb todo-light-keyword-faces))))
  (setq todo-light--regexp
	      (concat "\\(\\<"
		            "\\(" (mapconcat #'car todo-light-keyword-faces "\\|") "\\)"
		            "\\(?:\\>\\|\\>\\?\\)"
		            (and (not (equal todo-light-highlight-punctuation ""))
		                 (concat "[" todo-light-highlight-punctuation "]*"))
		            "\\)"))
  (setq todo-light--keywords
	      `(((lambda (bound) (todo-light--search nil bound))
	         (1 (todo-light--get-face) t t))))
  (font-lock-add-keywords nil todo-light--keywords t))

(defvar todo-light--syntax-table
  (let ((table (copy-syntax-table text-mode-syntax-table)))
    (modify-syntax-entry ?? "w" table)
    table))

(defun todo-light--search (&optional regexp bound backward)
  (unless regexp
    (setq regexp todo-light--regexp))
  (cl-block nil
    (while (let ((case-fold-search nil))
	           (with-syntax-table todo-light--syntax-table
	             (funcall (if backward #'re-search-backward #'re-search-forward)
			                  regexp bound t)))
      (cond ((or (apply #'derived-mode-p todo-light-text-modes)
		             (todo-light--inside-comment-or-string-p))
	           (cl-return t))
	          ((and bound (funcall (if backward #'<= #'>=) (point) bound))
	           (cl-return nil))))))

(defun todo-light--inside-comment-or-string-p ()
  (nth 8 (syntax-ppss)))

(defun todo-light--get-face ()
  (let* ((keyword (match-string 2))
	       (face (cdr (cl-find-if (lambda (elt)
				                          (string-match-p (format "\\`%s\\'" (car elt))
						                                      keyword))
				                        todo-light-keyword-faces))))
    (if (stringp face)
	      (list :inherit 'todo-light :foreground face)
      face)))

(defvar todo-light-mode-map (make-sparse-keymap)
  "Keymap for `todo-light-mode'.")

;;;###autoload
(define-minor-mode todo-light-mode
  "Highlight TODO and similar keywords in comments and strings."
  :lighter ""
  :keymap todo-light-mode-map
  :group 'todo-light
  (if todo-light-mode
      (todo-light--setup)
    (font-lock-remove-keywords nil todo-light--keywords))
  (when font-lock-mode
    (save-excursion
      (goto-char (point-min))
      (while (todo-light--search)
	      (save-excursion
	        (font-lock-fontify-region (match-beginning 0) (match-end 0) nil))))))

(defun todo-light--turn-on-mode-if-desired ()
  (when (and (apply #'derived-mode-p todo-light-activate-in-modes)
	           (not (derived-mode-p 'org-mode)))
    (todo-light-mode 1)))

;;;###autoload
(define-globalized-minor-mode global-todo-light-mode
  todo-light-mode todo-light--turn-on-mode-if-desired)

(defun todo-light-occur ()
  "Use `occur' to find all TODO or similar keywords.

This actually finds a superset of the highlighted keywords, because it uses a regexp instead of a
more sophisticated matcher. It also finds occurrences that are not within a string or comment.

This function was made obsolete in version 1.3.0, and will be removed from future versions."
  (interactive)
  (with-syntax-table todo-light--syntax-table
    (occur todo-light--regexp)))
(make-obsolete #'todo-light-occur nil "v1.3.0")

(provide 'todo-light)
;;; todo-light.el ends here
