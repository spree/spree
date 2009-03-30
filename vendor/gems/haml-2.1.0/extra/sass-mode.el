;;; sass-mode.el --- Major mode for editing Sass files

;; Copyright (c) 2007, 2008 Nathan Weizenbaum

;; Author: Nathan Weizenbaum
;; URL: http://github.com/nex3/haml/tree/master
;; Version: 1.0
;; Keywords: markup, language

;;; Commentary:

;; Because Sass's indentation schema is similar
;; to that of YAML and Python, many indentation-related
;; functions are similar to those in yaml-mode and python-mode.

;; To install, save this on your load path and add the following to
;; your .emacs file:
;;
;; (require 'sass-mode)

;;; Code:

(require 'haml-mode)

;; User definable variables

(defgroup sass nil
  "Support for the Sass template language."
  :group 'languages
  :prefix "sass-")

(defcustom sass-mode-hook nil
  "Hook run when entering Sass mode."
  :type 'hook
  :group 'sass)

(defcustom sass-indent-offset 2
  "Amount of offset per level of indentation."
  :type 'integer
  :group 'sass)

(defvar sass-non-block-openers
  '("^ *:[^ \t]+[ \t]+[^ \t]"
    "^ *[^ \t:]+[ \t]*[=:][ \t]*[^ \t]")
  "A list of regexps that match lines of Sass that couldn't have
text nested beneath them.")

;; Font lock

(defconst sass-font-lock-keywords
  '(("^ *\\(\t\\)"                            1 'haml-tab-face)
    ("^@.*"                                   0 font-lock-constant-face)
    ("\\(\'[^']*'\\)"                         1 font-lock-string-face append)
    ("\\(\"[^\"]*\"\\)"                       1 font-lock-string-face append)
    ("\\(#[0-9a-fA-F]\\{3\\}\\{1,2\\}\\>\\)"  1 font-lock-string-face append)
    ("\\(:[A-Za-z-]+\\|[A-Za-z-]+:\\)"        0 font-lock-constant-face append)
    ("![a-z0-9_-]+"                           0 font-lock-variable-name-face append)
    ("^ *\\(/[/*].*\\)$"                      1 font-lock-comment-face append)
    ("\\(?:^\\|,\\) *\\(#[a-z0-9_-]+\/?\\)"   1 font-lock-keyword-face)
    ("\\(?:^\\|,\\) *\\(\\.[a-z0-9_-]+\/?\\)" 1 font-lock-type-face)
    ("\\(?:^\\|,\\) *\\(&\\|[a-z0-9_]+\/?\\)" 1 font-lock-function-name-face)
    ("\\([=]\\)"                              0 font-lock-preprocessor-face prepend)
    ("\\(?:^\\|,\\) *\\(#[a-z0-9_]+\/?\\)"    (1 font-lock-keyword-face)
     ("\\.[a-z0-9_-]+" nil nil                (0 font-lock-type-face)))
    ("\\(?:^\\|,\\) *\\(\\.[a-z0-9_]+\/?\\)"  (1 font-lock-type-face)
     ("\\.[a-z0-9_-]+" nil nil                (0 font-lock-type-face)))
    ("\\(?:^\\|,\\) *\\(\\.[a-z0-9_]+\/?\\)"  (1 font-lock-type-face)
     ("\\#[a-z0-9_-]+" nil nil                (0 font-lock-keyword-face)))
    ("\\(?:^\\|,\\) *\\(&\\|[a-z0-9_]+\/?\\)" (1 font-lock-function-name-face)
     ("\\.[a-z0-9_-]+" nil nil                (0 font-lock-type-face)))
    ("\\(?:^\\|,\\) *\\(&\\|[a-z0-9_]+\/?\\)" (1 font-lock-function-name-face)
     ("\\#[a-z0-9_-]+" nil nil                (0 font-lock-keyword-face)))))

;; Constants

;; Mode setup

;;;###autoload
(define-derived-mode sass-mode haml-mode "Sass"
  "Major mode for editing Sass files."
  (set (make-local-variable 'haml-indent-function) 'sass-indent-p)
  (set (make-local-variable 'haml-indent-offset) sass-indent-offset)
  (setq font-lock-defaults '(sass-font-lock-keywords nil t)))

;; Indentation

(defun sass-indent-p ()
  "Returns true if the current line can have lines nested beneath it."
  (loop for opener in sass-non-block-openers
        unless (looking-at opener) return t
        return nil))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.sass$" . sass-mode))

;; Setup/Activation
(provide 'sass-mode)
;;; sass-mode.el ends here
