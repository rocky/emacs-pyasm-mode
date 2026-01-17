;;; pyasm-mode.el --- Mode for editing assembler code  -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 Rocky Bernstein

;; Author: Rocky Bernstein <rocky@gnu.org>
;; Version: 1.0.0
;; Maintainer: rocky@gnu.org
;; Keywords: languages
;; URL: https://github.com/rocky/emacs-pyasm-mode
;; Compatibility: GNU Emacs 24.x
;; Package-Requires: ((emacs "24.4") (compat "30.1.0.1"))

;;; License:

;; This file is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Font-lock mode for Python bytecode assembly from Python standard library
;; dis, or from the pydisasm program of xdis.

;; It defines a private abbrev table that can be used to save abbrevs
;; for assembler mnemonics.  It binds just four keys:
;;
;;	TAB		tab to next tab stop
;;	:		outdent preceding label, tab to tab stop
;;	C-j, C-m	newline and tab to tab stop
;;
;; Code is indented to the first tab stop level.

;; This mode runs two hooks:
;;   1) `pyasm-mode-set-comment-hook' before the part of the initialization
;;      depending on `asm-comment-char', and
;;   2) `pyasm-mode-hook' at the end of initialization.

;;; Code:

(require 'font-lock)

;; Attempt at a more complete pyasm coloring
;; (require 'mmm-mode)
;; Simpler python code section coloring
(defface pyasm-python-code-face '((t :inherit font-lock-doc-face))
  "Face for Python code in assembler comments.")

(defface pyasm-python-bytecode-hex-face
  '((t :inherit font-lock-type-face))
  "Face for Python code in hex section in instructions.")

(defface pyasm-section-face '((t :weight bold :foreground "black"))
  "Face for bold, black, even inside comments.")

(defgroup pyasm nil
  "Mode for editing assembler code."
  :link '(custom-group-link :tag "Font Lock Faces group" font-lock-faces)
  :group 'languages)

(defcustom pyasm-comment-char ?\#
  "The `comment-start' character assumed by Pyasm mode."
  :type 'character)

(defvar pyasm-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?\n "> b" st)
    (modify-syntax-entry ?/ ". 124b" st)
    (modify-syntax-entry ?* ". 23" st)
    st)
  "Syntax table used while in Pyasm mode.")

(defvar pyasm-mode-abbrev-table nil
  "Abbrev table used while in Pyasm mode.")
(define-abbrev-table 'pyasm-mode-abbrev-table ())

(defvar-keymap pyasm-mode-map
  :doc "Keymap for Pyasm mode."
  ;; Note that the comment character isn't set up until pyasm-mode is called.
  ":"
  #'pyasm-colon
  "C-c ;"
  #'comment-region)

(easy-menu-define pyasm-mode-menu pyasm-mode-map
  "Menu for Pyasm mode."
  '("Pyasm" ["Insert Colon"
     pyasm-colon
     :help "Insert a colon; if it follows a label, delete the label's indentation"]
    ["Insert Newline and Indent"
     newline-and-indent
     :help "Insert a newline, then indent according to major mode"]
    ["Comment Region"
     comment-region
     :help "Comment or uncomment each line in the region"]))

(defconst pyasm-operators
  '("ASYNC_GEN_WRAP"
    "BEFORE_ASYNC_WITH"
    "BEFORE_WITH"
    "BEGIN_FINALLY"
    "BINARY_ADD"
    "BINARY_AND"
    "BINARY_CALL"
    "BINARY_DIVIDE"
    "BINARY_FLOOR_DIVIDE"
    "BINARY_LSHIFT"
    "BINARY_MATRIX_MULTIPLY"
    "BINARY_MODULO"
    "BINARY_MULTIPLY"
    "BINARY_OP"
    "BINARY_OR"
    "BINARY_POWER"
    "BINARY_RSHIFT"
    "BINARY_SLICE"
    "BINARY_SUBSCR"
    "BINARY_SUBTRACT"
    "BINARY_TRUE_DIVIDE"
    "BINARY_XOR"
    "BREAK_LOOP"
    "BUILD_CLASS"
    "BUILD_CONST_KEY_MAP"
    "BUILD_FUNCTION"
    "BUILD_LIST"
    "BUILD_LIST_FROM_ARG"
    "BUILD_LIST_UNPACK"
    "BUILD_MAP"
    "BUILD_MAP_UNPACK"
    "BUILD_MAP_UNPACK_WITH_CALL"
    "BUILD_SET"
    "BUILD_SET_UNPACK"
    "BUILD_SLICE"
    "BUILD_STRING"
    "BUILD_TUPLE"
    "BUILD_TUPLE_UNPACK"
    "BUILD_TUPLE_UNPACK_WITH_CALL"
    "CALL"
    "CALL_FINALLY"
    "CALL_FUNCTION"
    "CALL_FUNCTION_EX"
    "CALL_FUNCTION_KW"
    "CALL_FUNCTION_VAR"
    "CALL_FUNCTION_VAR_KW"
    "CALL_INTRINSIC_1"
    "CALL_INTRINSIC_2"
    "CALL_KW"
    "CALL_METHOD"
    "CALL_METHOD_KW"
    "CHECK_EG_MATCH"
    "CHECK_EXC_MATCH"
    "CLEANUP_THROW"
    "COMPARE_OP"
    "CONTAINS_OP"
    "CONTINUE_LOOP"
    "CONVERT_VALUE"
    "COPY"
    "COPY_DICT_WITHOUT_KEYS"
    "COPY_FREE_VARS"
    "DELETE_ATTR"
    "DELETE_DEREF"
    "DELETE_FAST"
    "DELETE_GLOBAL"
    "DELETE_NAME"
    "DELETE_SLICE+0"
    "DELETE_SLICE+1"
    "DELETE_SLICE+2"
    "DELETE_SLICE+3"
    "DELETE_SLICE_0"
    "DELETE_SLICE_1"
    "DELETE_SLICE_2"
    "DELETE_SLICE_3"
    "DELETE_SUBSCR"
    "DICT_MERGE"
    "DICT_UPDATE"
    "DUP_TOP"
    "DUP_TOPX"
    "DUP_TOP_TWO"
    "END_ASYNC_FOR"
    "END_FINALLY"
    "END_FOR"
    "END_SEND"
    "ENTER_EXECUTOR"
    "EXEC_STMT"
    "EXIT_INIT_CHECK"
    "EXTENDED_ARG"
    "FORMAT_SIMPLE"
    "FORMAT_VALUE"
    "FORMAT_WITH_SPEC"
    "FOR_ITER"
    "FOR_LOOP"
    "GEN_START"
    "GET_AITER"
    "GET_ANEXT"
    "GET_AWAITABLE"
    "GET_ITER"
    "GET_LEN"
    "GET_YIELD_FROM_ITER"
    "IMPORT_FROM"
    "IMPORT_NAME"
    "IMPORT_STAR"
    "INPLACE_ADD"
    "INPLACE_AND"
    "INPLACE_DIVIDE"
    "INPLACE_FLOOR_DIVIDE"
    "INPLACE_LSHIFT"
    "INPLACE_MATRIX_MULTIPLY"
    "INPLACE_MODULO"
    "INPLACE_MULTIPLY"
    "INPLACE_OR"
    "INPLACE_POWER"
    "INPLACE_RSHIFT"
    "INPLACE_SUBTRACT"
    "INPLACE_TRUE_DIVIDE"
    "INPLACE_XOR"
    "INSTRUMENTED_CALL"
    "INSTRUMENTED_CALL_FUNCTION_EX"
    "INSTRUMENTED_CALL_KW"
    "INSTRUMENTED_END_FOR"
    "INSTRUMENTED_END_SEND"
    "INSTRUMENTED_FOR_ITER"
    "INSTRUMENTED_INSTRUCTION"
    "INSTRUMENTED_JUMP_BACKWARD"
    "INSTRUMENTED_JUMP_FORWARD"
    "INSTRUMENTED_LINE"
    "INSTRUMENTED_LOAD_SUPER_ATTR"
    "INSTRUMENTED_POP_JUMP_IF_FALSE"
    "INSTRUMENTED_POP_JUMP_IF_NONE"
    "INSTRUMENTED_POP_JUMP_IF_NOT_NONE"
    "INSTRUMENTED_POP_JUMP_IF_TRUE"
    "INSTRUMENTED_RESUME"
    "INSTRUMENTED_RETURN_CONST"
    "INSTRUMENTED_RETURN_VALUE"
    "INSTRUMENTED_YIELD_VALUE"
    "INTERPRETER_EXIT"
    "JUMP"
    "JUMP_ABSOLUTE"
    "JUMP_BACKWARD"
    "JUMP_BACKWARD_NO_INTERRUPT"
    "JUMP_FORWARD"
    "JUMP_IF_FALSE"
    "JUMP_IF_FALSE_OR_POP"
    "JUMP_IF_NOT_DEBUG"
    "JUMP_IF_NOT_EXC_MATCH"
    "JUMP_IF_TRUE"
    "JUMP_IF_TRUE_OR_POP"
    "JUMP_NO_INTERRUPT"
    "KW_NAMES"
    "LIST_APPEND"
    "LIST_EXTEND"
    "LIST_TO_TUPLE"
    "LOAD_ASSERTION_ERROR"
    "LOAD_ATTR"
    "LOAD_BUILD_CLASS"
    "LOAD_CLASSDEREF"
    "LOAD_CLOSURE"
    "LOAD_CONST"
    "LOAD_DEREF"
    "LOAD_FAST"
    "LOAD_FAST_AND_CLEAR"
    "LOAD_FAST_CHECK"
    "LOAD_FAST_LOAD_FAST"
    "LOAD_FROM_DICT_OR_DEREF"
    "LOAD_FROM_DICT_OR_GLOBALS"
    "LOAD_GLOBAL"
    "LOAD_GLOBALS"
    "LOAD_LOCAL"
    "LOAD_LOCALS"
    "LOAD_METHOD"
    "LOAD_NAME"
    "LOAD_REVDB_VAR"
    "LOAD_SMALL_INT"
    "LOAD_SUPER_ATTR"
    "LOAD_SUPER_METHOD"
    "LOAD_ZERO_SUPER_ATTR"
    "LOAD_ZERO_SUPER_METHOD"
    "LOOKUP_METHOD"
    "MAKE_CELL"
    "MAKE_CLOSURE"
    "MAKE_FUNCTION"
    "MAP_ADD"
    "MATCH_CLASS"
    "MATCH_KEYS"
    "MATCH_MAPPING"
    "MATCH_SEQUENCE"
    "NOP"
    "NOT_TAKEN"
    "POP_BLOCK"
    "POP_EXCEPT"
    "POP_FINALLY"
    "POP_JUMP_BACKWARD_IF_FALSE"
    "POP_JUMP_BACKWARD_IF_NONE"
    "POP_JUMP_BACKWARD_IF_NOT_NONE"
    "POP_JUMP_BACKWARD_IF_TRUE"
    "POP_JUMP_FORWARD_IF_FALSE"
    "POP_JUMP_FORWARD_IF_NONE"
    "POP_JUMP_FORWARD_IF_NOT_NONE"
    "POP_JUMP_FORWARD_IF_TRUE"
    "POP_JUMP_IF_FALSE"
    "POP_JUMP_IF_NONE"
    "POP_JUMP_IF_NOT_NONE"
    "POP_JUMP_IF_TRUE"
    "POP_TOP"
    "PRECALL"
    "PREP_RERAISE_STAR"
    "PRINT_EXPR"
    "PRINT_ITEM"
    "PRINT_ITEM_TO"
    "PRINT_NEWLINE"
    "PRINT_NEWLINE_TO"
    "PUSH_EXC_INFO"
    "PUSH_NULL"
    "RAISE_EXCEPTION"
    "RAISE_VARARGS"
    "RERAISE"
    "RESERVED"
    "RESERVE_FAST"
    "RESUME"
    "RETURN_CONST"
    "RETURN_GENERATOR"
    "RETURN_VALUE"
    "ROT_FOUR"
    "ROT_N"
    "ROT_THREE"
    "ROT_TWO"
    "SEND"
    "SETUP_ANNOTATIONS"
    "SETUP_ASYNC_WITH"
    "SETUP_CLEANUP"
    "SETUP_EXCEPT"
    "SETUP_FINALLY"
    "SETUP_LOOP"
    "SETUP_WITH"
    "SET_ADD"
    "SET_FUNCTION_ATTRIBUTE"
    "SET_FUNC_ARGS"
    "SET_LINENO"
    "SET_UPDATE"
    "SLICE+0"
    "SLICE+1"
    "SLICE+2"
    "SLICE+3"
    "SLICE_0"
    "SLICE_1"
    "SLICE_2"
    "SLICE_3"
    "STOP_CODE"
    "STORE_ANNOTATION"
    "STORE_ATTR"
    "STORE_DEREF"
    "STORE_FAST"
    "STORE_FAST_LOAD_FAST"
    "STORE_FAST_MAYBE_NULL"
    "STORE_FAST_STORE_FAST"
    "STORE_GLOBAL"
    "STORE_LOCALS"
    "STORE_MAP"
    "STORE_NAME"
    "STORE_SLICE"
    "STORE_SLICE+0"
    "STORE_SLICE+1"
    "STORE_SLICE+2"
    "STORE_SLICE+3"
    "STORE_SLICE_0"
    "STORE_SLICE_1"
    "STORE_SLICE_2"
    "STORE_SLICE_3"
    "STORE_SUBSCR"
    "SWAP"
    "TO_BOOL"
    "UNARY_CALL"
    "UNARY_CONVERT"
    "UNARY_INVERT"
    "UNARY_NEGATIVE"
    "UNARY_NOT"
    "UNARY_POSITIVE"
    "UNPACK_ARG"
    "UNPACK_EX"
    "UNPACK_LIST"
    "UNPACK_SEQUENCE"
    "UNPACK_TUPLE"
    "UNPACK_VARARG"
    "WITH_CLEANUP"
    "WITH_CLEANUP_FINISH"
    "WITH_CLEANUP_START"
    "WITH_EXCEPT_START"
    "YIELD_FROM"
    "YIELD_VALUE")
  "List of all Python operator names.")

(defconst pyasm-font-lock-keywords
  (list
   ;; (cons "# Method Name:" 'pyasm-section-face)

   (cons " \\([0-9]+\\) " 'font-lock-function-name-face)

   ;; Operator names
   (cons
    (concat "\\<" (regexp-opt pyasm-operators t) "\\>")
    'font-lock-variable-name-face)

   ;; Jumps to line number
   (cons "(to [0-9]+)" 'font-lock-type-face)

   ;; Labels at start of line
   (cons "^\s*L?[0-9]+:" 'font-lock-constant-face)

   ;; Pre 3.6 Operand
   ;; (cons "|[0-9a-f][0-9a-f] [0-9a-f ][0-9a-f ][0-9a-f ][0-9a-f ][0-9[a-f ]" 'font-lock-type-face)
   ;; The above doesn't work. The below is close, but misses the first byte of a Pre-3.6 2-byte operand.
   (cons "|[0-9a-f][0-9a-f]" 'font-lock-type-face)
   (cons "[0-9a-f][0-9a-f]|" 'font-lock-type-face)

   ;; Label as an operand
   (cons "L[0-9]+ " 'font-lock-constant-face)

   ;; Less complete Python coloring
   (cons "\\(; .*$\\)" 'font-lock-doc-face)

   ;; '("^\\sw*\\([0-9]+:\\)"
   ;;   1 font-lock-constant-face)
   ;; '("^\\((\\sw+)\\)?\\s +\\(\\(\\.?\\sw\\|\\s_\\)+\\(\\.\\sw+\\)*\\)"
   ;;   2 font-lock-keyword-face)
   ;; '("^\\sw*\\([0-9]+:\\sw*[0-9]+\\)"
   ;;   1 font-lock-constant-face)
   ;; '("^\\((\\sw+)\\)?\\s +\\(\\(\\.?\\sw\\|\\s_\\)+\\(\\.\\sw+\\)*\\)"
   ;;   1 font-lock-constant-face)
   )
  "Additional expressions to highlight in Python Assembler mode.")

;;;###autoload
(define-derived-mode
 pyasm-mode
 prog-mode
 "Python Assembler"
 "Major mode for Python dis and pydisasm (from xdis) assembler code.
Features a private abbrev table and the following bindings:

\\[pyasm-colon]\toutdent a preceding label, tab to next tab stop.
\\[tab-to-tab-stop]\ttab to next tab stop.
\\[newline-and-indent]\tnewline, then tab to next tab stop.
\\[pyasm-comment]\tsmart placement of assembler comments.

The character used for making comments is set by the variable
`pyasm-comment-char' (which defaults to `?\\;').

Alternatively, you may set this variable in `pyasm-mode-set-comment-hook',
which is called near the beginning of mode initialization.

Turning on Pyasm mode runs the hook `pyasm-mode-hook' at the end
of initialization.

Special commands:
\\{pyasm-mode-map}"
 (setq local-abbrev-table pyasm-mode-abbrev-table)
 (setq-local font-lock-defaults '(pyasm-font-lock-keywords))
 (setq-local indent-line-function #'pyasm-indent-line)
 ;; Stay closer to the old TAB behavior (was tab-to-tab-stop).
 (setq-local tab-always-indent nil)

 (run-hooks 'pyasm-mode-set-comment-hook)
 ;; Make our own local child of `pyasm-mode-map'
 ;; so we can define our own comment character.
 (use-local-map (nconc (make-sparse-keymap) pyasm-mode-map))
 (local-set-key (vector pyasm-comment-char) #'pyasm-comment)
 (set-syntax-table (make-syntax-table pyasm-mode-syntax-table))
 (modify-syntax-entry pyasm-comment-char "< b")

 (setq-local comment-start (string pyasm-comment-char))
 (setq-local comment-add 1)
 (setq-local comment-start-skip "\\(?:\\s<+\\|/[/*]+\\)[ \t]*")
 (setq-local comment-end-skip "[ \t]*\\(\\s>\\|\\*+/\\)")
 (setq-local comment-end ""))

(defun pyasm-indent-line ()
  "Auto-indent the current line."
  (interactive)
  (let* ((savep (point))
         (indent
          (condition-case nil
              (save-excursion
                (forward-line 0)
                (skip-chars-forward " \t")
                (if (>= (point) savep)
                    (setq savep nil))
                (max (pyasm-calculate-indentation) 0))
            (error
             0))))
    (if savep
        (save-excursion (indent-line-to indent))
      (indent-line-to indent))))

(defun pyasm-calculate-indentation ()
  "Return the column number for where the next field should start."
  (or
   ;; Flush labels to the left margin.
   (and (looking-at "\\(\\sw\\|\\s_\\)+:") 0)
   ;; Same thing for `;;;' comments.
   (and (looking-at "\\s<\\s<\\s<") 0)
   ;; Simple `;' comments go to the comment-column.
   (and (looking-at "\\s<\\(S<\\|\\'\\)") comment-column)
   ;; The rest goes at the first tab stop.
   (indent-next-tab-stop 0)))

(defun pyasm-colon ()
  "Insert a colon; if it follows a label, delete the label's indentation."
  (interactive)
  (let ((labelp nil))
    (save-excursion
      (skip-syntax-backward "w_")
      (skip-syntax-backward " ")
      (if (setq labelp (bolp))
          (delete-horizontal-space)))
    (call-interactively #'self-insert-command)
    (when labelp
      (delete-horizontal-space)
      (tab-to-tab-stop))))

(define-obsolete-function-alias
  'pyasm-newline #'newline-and-indent "27.1")

;; For a python-mode handling. Not working yet.
;; (mmm-add-classes
;;  '((pyasm-python-in-comment
;;     :submode python-mode
;;     :face mmm-code-submode-face
;;     :front "^;[ \t]*"
;;     :include-front t
;;     :back "$"
;;     :end-not-begin t
;;     :match-submode nil ;; always python-mode
;;     :delimiter-mode nil
;;     :insert ((?p "Python comment" "; " "" nil)))))

;; (mmm-add-mode-ext-class 'pyasm-mode nil 'pyasm-python-in-comment)
;; (add-hook 'pyasm-mode-hook 'mmm-mode)


(provide 'pyasm-mode)

;;; pyasm-mode.el ends here
