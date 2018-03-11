;;; guile-syntax-highlight --- General-purpose syntax highlighter
;;; Copyright © 2017 David Thompson <davet@gnu.org>
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
;; Syntax highlighting for C.
;;
;;; Code:

(define-module (syntax-highlight c)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-11)
  #:use-module (srfi srfi-26)
  #:use-module (syntax-highlight lexers)
  #:export (lex-c))

(define %c-reserved-words
  '("auto" "break" "case" "char" "const" "continue" "default" "do"
    "double" "else" "enum" "extern" "float" "for" "goto" "if" "int"
    "long" "register" "return" "short" "signed" "sizeof" "static"
    "struct" "switch" "typedef" "union" "unsigned" "void" "volatile"
    "while"))

(define (c-reserved-word? str)
  "Return #t if STR is a C keyword."
  (any (cut string=? <> str) %c-reserved-words))

;; Yeah, semicolon isn't an operator, but it's convenient to put it in
;; this list.
(define %c-operators
  '(";" "," "=" "?" ":" "||" "&&" "|" "^" "&" "==" "!=" "<=" ">=" "<" ">"
    "<<" ">>" "*" "/" "%" "~" "!" "++" "--" "+" "-" "->" "." "[" "]"))

(define lex-c-operator
  (lex-any* (map lex-string %c-operators)))

(define char-set:c-identifier
  (char-set #\a #\b #\c #\d #\e #\f #\g #\h #\i #\j #\k #\l #\m #\n #\o
            #\p #\q #\r #\s #\t #\u #\v #\w #\x #\y #\z
            #\A #\B #\C #\D #\E #\F #\G #\H #\I #\J #\K #\L #\M #\N #\O
            #\P #\Q #\R #\S #\T #\U #\V #\W #\X #\Y #\Z
            #\_ #\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9))

(define lex-c-identifier
  (lex-char-set char-set:c-identifier))

(define (lex-map2 proc lexer)
  (lambda (tokens cursor)
    (let-values (((result remainder) (lexer tokens cursor)))
      (if result
          (match (token-take result 2)
            ((second first) ; accumulator tokens are in reverse order
             (values (token-add (token-drop result 2)
                                (proc first second))
                     remainder)))
          (fail)))))

(define (lex-map3 proc lexer)
  (lambda (tokens cursor)
    (let-values (((result remainder) (lexer tokens cursor)))
      (if result
          (match (token-take result 3)
            ((third second first) ; accumulator tokens are in reverse order
             (values (token-add (token-drop result 3)
                                (proc first second third))
                     remainder)))
          (fail)))))

(define lex-c-preprocessor
  (lex-any (lex-map2 string-append
                     (lex-all (lex-string "#")
                              lex-c-identifier))
           (lex-map3 string-append
                     (lex-all (lex-string "#")
                              lex-whitespace
                              lex-c-identifier))))

(define lex-c
  (lex-consume
   (lex-any (lex-char-set char-set:whitespace)
            (lex-tag 'open (lex-any* (map lex-string '("(" "[" "{"))))
            (lex-tag 'close (lex-any* (map lex-string '(")" "]" "}"))))
            (lex-tag 'comment (lex-any (lex-delimited "//" #:until "\n")
                                       (lex-delimited "/*" #:until "*/")))
            (lex-tag 'keyword lex-c-preprocessor)
            (lex-tag 'special (lex-filter c-reserved-word? lex-c-identifier))
            (lex-tag 'symbol lex-c-identifier)
            ;; This is naive, but for now we'll just treat
            ;; preprocessor includes like '<stdio.h>' as strings, even
            ;; if the text isn't next to an '#include'.
            (lex-tag 'string (lex-any (lex-delimited "\"")
                                      (lex-delimited "<" #:until ">")))
            lex-c-operator)))
