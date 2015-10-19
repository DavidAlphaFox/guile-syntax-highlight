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
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-11)
  #:use-module (srfi srfi-41)
  #:use-module (syntax-highlight parsers)
  #:export (%default-special-symbols
            %default-special-regexps
            make-scheme-highlighter
            scheme-highlighter))

(define char-set:lisp-delimiters
  (char-set-union char-set:whitespace
                  (char-set #\( #\) #\[ #\] #\{ #\})))

(define (lisp-delimiter? char)
  (char-set-contains? char-set:lisp-delimiters char))

(define parse-symbol-chars
  (parse-char-set
   (char-set-complement char-set:lisp-delimiters)))

(define (parse-specials special-words)
  "Create a parser for SPECIAL-WORDS, a list of important terms for a
language."
  (define (special word)
    (let ((parser (tagged-parser 'special (parse-string word))))
      (lambda (stream)
        (let-values (((result rest-of-stream) (parser stream)))
          (if (and result (lisp-delimiter? (stream-car stream)))
              (values result rest-of-stream)
              (parse-fail stream))))))

  (fold parse-either parse-fail (map special special-words)))

(define (parse-specials/regexp special-regexps)
  (let ((merged-regexp
         (string-join (map (lambda (regexp)
                             (string-append "(" regexp ")"))
                           special-regexps)
                      "|")))
    (tagged-parser 'special
                   (parse-regexp merged-regexp parse-symbol-chars))))

(define (parse-openers openers)
  (define (open opener)
    (tagged-parser 'open (parse-string opener)))

  (fold parse-either parse-fail (map open openers)))

(define (parse-closers closers)
  (define (close closer)
    (tagged-parser 'close (parse-string closer)))

  (fold parse-either parse-fail (map close closers)))

(define parse-symbol
  (tagged-parser 'symbol
                 (parse-char-set
                  (char-set-complement char-set:lisp-delimiters))))

(define parse-keyword
  (tagged-parser 'keyword
                 (parse-map string-concatenate
                            (parse-each (parse-string "#:")
                                        parse-symbol-chars))))

(define parse-string-literal
  (tagged-parser 'string (parse-delimited "\"")))

(define parse-comment
  (tagged-parser 'comment (parse-delimited ";" #:until "\n")))

(define parse-quoted-symbol
  (tagged-parser 'symbol (parse-delimited "#{" #:until "}#")))

(define %default-special-symbols
  '("define" "begin" "call-with-current-continuation" "call/cc"
    "call-with-input-file" "call-with-output-file"
    "case" "cond"
    "do" "else" "if"
    "lambda" "λ"
    "let" "let*" "let-syntax" "letrec" "letrec-syntax"
    "export" "import" "library" "define-module" "use-module"
    "let-values" "let*-values"
    "and" "or"
    "delay" "force"
    "map" "for-each"
    "syntax" "syntax-rules"))

(define %default-special-regexps
  '("^define"))

(define* (make-scheme-highlighter special-symbols special-regexps)
  "Create a syntax highlighting procedure for Scheme that associates
the 'special' tag for symbols appearing in the list SPECIAL-SYMBOLS or
matching a regular expression in SPECIAL-REGEXPS."
  (parse-many
   (parse-any parse-whitespace
              (parse-openers '("(" "[" "{"))
              (parse-closers '(")" "]" "}"))
              (parse-specials special-symbols)
              (parse-specials/regexp special-regexps)
              parse-string-literal
              parse-comment
              parse-keyword
              parse-quoted-symbol
              parse-symbol)))

(define scheme-highlighter
  (make-scheme-highlighter %default-special-symbols
                           %default-special-regexps))
