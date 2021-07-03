;;; guile-syntax-highlight --- General-purpose syntax highlighter
;;; Copyright © 2021 Julien Lepiller <julien@lepiller.eu>
;;;
;;; Guile-syntax-highlight is free software; you can redistribute it
;;; and/or modify it under the terms of the GNU Lesser General Public
;;; License as published by the Free Software Foundation; either
;;; version 3 of the License, or (at your option) any later version.
;;;
;;; Guile-syntax-highlight is distributed in the hope that it will be
;;; useful, but WITHOUT ANY WARRANTY; without even the implied
;;; warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
;;; See the GNU Lesser General Public License for more details.
;;;
;;; You should have received a copy of the GNU Lesser General Public
;;; License along with guile-syntax-highlight.  If not, see
;;; <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Syntax highlighting for gitignore files.
;;
;;; Code:

(define-module (syntax-highlight gitignore)
  #:use-module (syntax-highlight lexers)
  #:export (lex-gitignore))

(define lex-line
  (lex-consume-until
    (lex-string "\n")
    (lex-any
      (lex-tag 'special (apply lex-any (map lex-string '("*" "**" "?"))))
      (lex-tag 'range (lex-delimited "[" #:until "]"))
      (apply lex-any (map lex-string '("\\!" "\\*" "\\\\" "\\?" "\\[")))
      (lex-char-set (char-set-complement (char-set #\newline #\\ #\* #\? #\[))))
    #:tag 'line))

(define lex-gitignore
  (lex-consume
    (lex-any (lex-tag 'comment (lex-delimited "#" #:until "\n"))
             (lex-tag 'special (lex-string "!"))
             lex-line)))
