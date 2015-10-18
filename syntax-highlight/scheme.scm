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
  #:export (scheme-highlighter))

(define char-set:lisp-delimiters
  (char-set-union char-set:whitespace
                  (char-set #\( #\) #\[ #\] #\{ #\})))

(define (lisp-delimiter? char)
  (char-set-contains? char-set:lisp-delimiters char))

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

  (fold parse-either parse-never (map special special-words)))

(define (parse-openers openers)
  (define (open opener)
    (tagged-parser 'open (parse-string opener)))

  (fold parse-either parse-never (map open openers)))

(define (parse-closers closers)
  (define (close closer)
    (tagged-parser 'close (parse-string closer)))

  (fold parse-either parse-never (map close closers)))

(define parse-symbol
  (tagged-parser 'symbol
                 (parse-char-set
                  (char-set-complement char-set:lisp-delimiters))))

(define parse-keyword
  (tagged-parser 'keyword
                 (parse-map string-concatenate
                            (parse-each (parse-string "#:")
                                        (parse-char-set
                                         (char-set-complement
                                          char-set:lisp-delimiters))))))

(define parse-string-literal
  (tagged-parser 'string (parse-delimited "\"")))

(define parse-comment
  (tagged-parser 'comment (parse-delimited ";" #:until "\n")))

(define parse-quoted-symbol
  (tagged-parser 'symbol (parse-delimited "#{" #:until "}#")))

(define scheme-highlighter
  (parse-many
   (parse-any parse-whitespace
              (parse-openers '("(" "[" "{"))
              (parse-closers '(")" "]" "}"))
              (parse-specials '("define" "lambda"))
              parse-string-literal
              parse-comment
              parse-keyword
              parse-quoted-symbol
              parse-symbol)))

;; (scheme-highlighter
;;  (string->stream
;;   "(define* (foo bar #:key (baz 'quux))
;;   \"This is a docstring!\"
;;   #u8(1 2 3)
;;   (1+ bar))"))
