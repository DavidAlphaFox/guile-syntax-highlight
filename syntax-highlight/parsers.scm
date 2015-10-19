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
;; Parsing utilities.
;;
;;; Code:

(define-module (syntax-highlight parsers)
  #:use-module (ice-9 match)
  #:use-module (ice-9 regex)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-11)
  #:use-module (srfi srfi-26)
  #:use-module (srfi srfi-41)
  #:export (parse-fail
            parse-bind
            parse-return
            parse-lift
            parse-never
            parse-map
            parse-filter
            parse-either
            parse-both
            parse-any
            parse-each
            parse-many
            parse-string
            parse-char-set
            parse-whitespace
            parse-delimited
            parse-regexp
            tagged-parser))

;;;
;;; Parser combinators
;;;

(define (parse-fail stream)
  "Return a failed parse value with STREAM as the remainder."
  (values #f stream))

(define (parse-bind proc parser)
  (lambda (stream)
    (let-values (((result stream) (parser stream)))
      (if result
          ((proc result) stream)
          (parse-fail stream)))))

(define (parse-return x)
  "Return a parser that always yields X as the parse result."
  (lambda (stream)
    (values x stream)))

(define (parse-lift proc)
  "Return a procedure that wraps the result of PROC in a parser."
  (lambda args
    (parse-return (apply proc args))))

(define (parse-never stream)
  "Always fail to parse STREAM."
  (parse-fail stream))

(define (parse-map proc parser)
  "Return a new parser that applies PROC to result of PARSER."
  (parse-bind (parse-lift proc) parser))

(define (parse-filter predicate parser)
  "Create a new parser that succeeds when PARSER is successful and
PREDICATE is satisfied with the result."
  (lambda (stream)
    (let-values (((result remaining) (parser stream)))
      (if (and result (predicate result))
          (values result remaining)
          (parse-fail stream)))))

(define (parse-either first second)
  "Create a parser that tries to parse with FIRST or, if that fails,
parses SECOND."
  (lambda (stream)
    (let-values (((result stream) (first stream)))
      (if result
          (values result stream)
          (second stream)))))

(define (parse-both first second)
  "Create a parser that returns a pair of the results of the parsers
FIRST and SECOND if both are successful."
  (lambda (stream)
    (let-values (((result1 stream) (first stream)))
      (if result1
          (let-values (((result2 stream) (second stream)))
            (if result2
                (values (cons result1 result2) stream)
                (parse-fail stream)))
          (parse-fail stream)))))

(define (parse-any . parsers)
  "Create a parser that returns the result of the first successful
parser in PARSERS.  This parser fails if no parser in PARSERS
succeeds."
  (fold-right parse-either parse-never parsers))

(define (parse-each . parsers)
  "Create a parser that builds a list of the results of PARSERS.  This
parser fails without consuming any input if any parser in PARSERS
fails."
  (fold-right parse-both (parse-return '()) parsers))

(define (parse-many parser)
  "Create a parser that uses PARSER as many times as possible until it
fails and return the results of each successful parse in a list.  This
parser always succeeds."
  (lambda (stream)
    (let loop ((stream stream)
               (results '()))
      (let-values (((result remaining) (parser stream)))
        (if result
            (loop remaining (cons result results))
            (values (reverse results)
                    remaining))))))

(define stream->string (compose list->string stream->list))

(define (parse-string str)
  "Create a parser that succeeds when the front of the stream contains
the character sequence in STR."
  (lambda (stream)
    (let ((input (stream->string (stream-take (string-length str) stream))))
      (if (string=? str input)
          (values str (stream-drop (string-length str) stream))
          (parse-fail stream)))))

(define (parse-char-set char-set)
  "Create a parser that returns a string containing a contiguous
sequence of characters that belong to CHAR-SET."
  (lambda (stream)
    (let loop ((stream stream)
               (result '()))
      (define (stringify)
        (if (null? result)
            (parse-fail stream)
            (values (list->string (reverse result))
                    stream)))

      (stream-match stream
        (() (stringify))
        ((head . rest)
         (if (char-set-contains? char-set head)
             (loop rest (cons head result))
             (stringify)))))))

(define parse-whitespace
  (parse-char-set char-set:whitespace))

(define* (parse-delimited str #:key (until str) (escape #\\))
  "Create a parser that parses a delimited character sequence
beginning with the string STR and ending with the string UNTIL.
Within the sequence, ESCAPE is recognized as the escape character."
  (let ((parse-str    (parse-string str))
        (parse-until  (parse-string until)))

    (define (stringify lst stream)
      (values (list->string (reverse lst))
              stream))

    (define (parse-until-maybe stream)
      (let-values (((result remaining) (parse-until stream)))
        (and result remaining)))

    (lambda (stream)
      (let-values (((result remaining) (parse-str stream)))
        (if result
            (let loop ((stream remaining)
                       (result (reverse (string->list str))))
              (cond
               ((stream-null? stream)
                (stringify result stream))
               ;; Escape character.
               ((eqv? (stream-car stream) escape)
                (stream-match (stream-cdr stream)
                  (() (stringify result stream-null))
                  ((head . rest)
                   (loop rest (cons* head escape result)))))
               ((parse-until-maybe stream) =>
                (lambda (remaining)
                  (stringify (append (reverse (string->list until)) result)
                             remaining)))
               (else
                (loop (stream-cdr stream) (cons (stream-car stream) result)))))
            (parse-fail stream))))))

(define (parse-regexp regexp parser)
  "Create a parser that succeeds if the result of PARSER is a string
that matches the string REGEXP."
  (let ((rx (make-regexp regexp)))
    (parse-filter (lambda (result)
                    (regexp-match? (regexp-exec rx result)))
                  parser)))

(define (tagged-parser tag parser)
  "Create a parser that wraps the result of PARSER in a two element
list whose first element is TAG."
  (parse-map (cut list tag <>) parser))
