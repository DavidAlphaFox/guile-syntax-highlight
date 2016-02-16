;;; guile-syntax-highlight --- General-purpose syntax highlighter
;;; Copyright © 2015 David Thompson <davet@gnu.org>
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
;; Syntax highlighting for Scheme.
;;
;;; Code:

(define-module (syntax-highlight scheme)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-11)
  #:use-module (srfi srfi-26)
  #:use-module (syntax-highlight lexers)
  #:export (%default-special-symbols
            %default-special-regexps
            make-scheme-lexer
            lex-scheme))

(define char-set:lisp-delimiters
  (char-set-union char-set:whitespace
                  (char-set #\( #\) #\[ #\] #\{ #\})))

(define char-set:lisp-symbol
  (char-set-complement char-set:lisp-delimiters))

(define %default-special-symbols
  '("begin" "call-with-current-continuation" "call/cc"
    "call-with-input-file" "call-with-output-file"
    "case" "cond"
    "do" "else" "if"
    "lambda" "λ"
    "let" "let*" "let-syntax" "letrec" "letrec-syntax"
    "let-values" "let*-values"
    "export" "import" "library" "use-module"
    "and" "or"
    "delay" "force"
    "map" "for-each"))

(define %default-special-prefixes
  '("define" "syntax"))

(define (lex-special-symbol sym)
  (lex-filter (lambda (str)
                (string=? sym str))
              (lex-char-set char-set:lisp-symbol)))

(define (lex-special-symbol symbols prefixes)
  (lex-filter (lambda (str)
                (or (any (cut string=? symbols <>) symbols)
                    (any (cut string-prefix? <> str) prefixes)))
              (lex-char-set char-set:lisp-symbol)))

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

(define (make-scheme-lexer special-symbols special-prefixes)
  "Return a lexer that highlights Scheme source code.  Tag strings
that are in SPECIAL-SYMBOLS or match one of the string prefixes in
SPECIAL-PREFIXES with the 'special' tag."
  (lex-consume
   (lex-any (lex-char-set char-set:whitespace)
            (lex-tag 'open (lex-any* (map lex-string '("(" "[" "{"))))
            (lex-tag 'close (lex-any* (map lex-string '(")" "]" "}"))))
            (lex-tag 'comment (lex-delimited ";" #:until "\n"))
            (lex-tag 'multi-line-comment
                     (lex-delimited "#|" #:until "|#" #:nested? #t))
            (lex-tag 'special
                     (lex-filter (lambda (str)
                                   (or (any (cut string=? <> str)
                                            special-symbols)
                                       (any (cut string-prefix? <> str)
                                            special-prefixes)))
                                 (lex-char-set char-set:lisp-symbol)))
            (lex-tag 'string (lex-delimited "\""))
            (lex-tag 'keyword
                     (lex-map2 string-append
                               (lex-all (lex-string "#:")
                                        (lex-char-set char-set:lisp-symbol))))
            (lex-tag 'symbol
                     (lex-any (lex-delimited "#{" #:until "}#")
                              (lex-char-set char-set:lisp-symbol))))))

(define lex-scheme
  (make-scheme-lexer %default-special-symbols %default-special-prefixes))
