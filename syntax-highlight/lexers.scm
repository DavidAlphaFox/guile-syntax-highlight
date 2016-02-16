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
;; Lexing utilities.
;;
;;; Code:

(define-module (syntax-highlight lexers)
  #:use-module (ice-9 match)
  #:use-module (ice-9 regex)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (srfi srfi-11)
  #:use-module (srfi srfi-26)
  #:export (make-cursor
            cursor?
            cursor-text
            cursor-position
            cursor-end?
            move-cursor
            move-cursor-by
            move-cursor-to-end
            string->cursor
            cursor->string

            empty-tokens
            token-add
            token-drop
            token-take
            token-peek
            tokens->list

            fail
            lex-fail
            lex-identity
            lex-cons
            lex-bind
            lex-filter
            lex-any*
            lex-any
            lex-all*
            lex-all
            lex-zero-or-more
            lex-consume
            lex-maybe
            lex-regexp
            lex-string
            lex-char-set
            lex-whitespace
            lex-delimited
            lex-tag))

(define (string-prefix?* s1 s2 start-s2)
  (string-prefix? s1 s2 0 (string-length s1) start-s2))


;;;
;;; Cursor
;;;

(define-record-type <cursor>
  (make-cursor text position)
  cursor?
  (text cursor-text)
  (position cursor-position))

(define (cursor-end? cursor)
  "Return #t if the cursor is at the end of the text."
  (>= (cursor-position cursor) (string-length (cursor-text cursor))))

(define (move-cursor cursor position)
  "Move CURSOR to the character at POSITION."
  (make-cursor (cursor-text cursor) position))

(define (move-cursor-by cursor offset)
  "Move CURSOR by OFFSET characters relative to its current
position."
  (move-cursor cursor (+ (cursor-position cursor) offset)))

(define (move-cursor-to-end cursor)
  (move-cursor cursor (string-length (cursor-text cursor))))

(define (string->cursor str)
  (make-cursor str 0))

(define (cursor->string cursor)
  (substring (cursor-text cursor) (cursor-position cursor)))


;;;
;;; Tokens
;;;

(define empty-tokens '())

(define (token-add tokens new-token)
  (cons new-token tokens))

(define (token-peek tokens)
  (car tokens))

(define (token-drop tokens n)
  (drop tokens n))

(define (token-take tokens n)
  (take tokens n))

(define (tokens->list tokens)
  ;; Tokens are accumulated as a stack i.e. in reverse order.
  (reverse tokens))


;;;
;;; Lexers
;;;

(define (fail)
  (values #f #f))

(define (lex-fail tokens cursor)
  "Always fail to parse lexemes without advancing CURSOR or altering
TOKENS."
  (fail))

(define (lex-identity tokens cursor)
  (values tokens cursor))

(define (lex-bind proc lexer)
  "Return a lexer that applies the result of LEXER to PROC, a
procedure that returns a lexer, and then applies that new lexer."
  (lambda (tokens cursor)
    (let-values (((result remainder) (lexer tokens cursor)))
      (if result
          ((proc result) remainder)
          (fail)))))

(define (lex-filter predicate lexer)
  "Return a lexer that succeeds when LEXER succeeds and the head of
the tokens queue satisfies PREDICATE."
  (lambda (tokens cursor)
    (let-values (((result remainder) (lexer tokens cursor)))
      (if (and result (predicate (token-peek result)))
          (values result remainder)
          (fail)))))

(define (lex-any* lexers)
  "Return a lexer that succeeds with the result of the first
successful lexer in LEXERS or fails if all lexers fail."
  (define (either a b)
    (lambda (tokens cursor)
      (let-values (((result remainder) (a tokens cursor)))
        (if result
            (values result remainder)
            (b tokens cursor)))))

  (fold-right either lex-fail lexers))

(define (lex-any . lexers)
  "Return a lexer that succeeds with the result of the first
successful lexer in LEXERS or fails if all lexers fail."
  (lex-any* lexers))

(define (lex-all* lexers)
  "Return a lexer that succeeds with the results of all LEXERS in
order, or fails if any lexer fails."
  (define (both a b)
    (lambda (tokens cursor)
      (let-values (((result-a remainder-a) (a tokens cursor)))
        (if result-a
            (let-values (((result-b remainder-b) (b result-a remainder-a)))
              (if result-b
                  (values result-b remainder-b)
                  (fail)))
            (fail)))))

  (fold-right both lex-identity lexers))

(define (lex-all . lexers)
  "Return a lexer that succeeds with the results of all LEXERS in
order, or fails if any lexer fails."
  (lex-all* lexers))

(define (lex-zero-or-more lexer)
  "Create a lexer that uses LEXER as many times as possible until it
fails and return the results of each success in a list.  The lexer
always succeeds."
  (define (lex tokens cursor)
    (let-values (((result remainder) (lexer tokens cursor)))
      (if result
          (lex result remainder)
          (values tokens cursor))))

  lex)

(define (lex-consume lexer)
  "Return a lexer that always succeeds with a list of as many
consecutive successful applications of LEXER as possible, consuming
the entire input text.  Sections of text that could not be lexed are
returned as plain strings."
  (define (substring* cursor start)
    (substring (cursor-text cursor) start (cursor-position cursor)))

  (define (consume tokens cursor)
    (if (cursor-end? cursor)
        (values tokens cursor)
        (let-values (((result remainder) (lexer tokens cursor)))
          (if result
              (consume result remainder)
              (values (token-add tokens (cursor->string cursor))
                      (move-cursor-to-end cursor))))))

  consume)

(define (lex-maybe lexer)
  "Create a lexer that always succeeds, but tries to use LEXER.  If
LEXER succeeds, its result is returned, otherwise the empty string is
returned without consuming any input."
  (lambda (tokens cursor)
    (let-values (((result remainder) (lexer tokens cursor)))
      (if result
          (values result remainder)
          (values tokens cursor)))))

(define (lex-regexp pattern)
  "Return a lexer that succeeds with the matched substring when the
input matches the string PATTERN."
  (let ((rx (make-regexp (string-append "^" pattern))))
    (lambda (tokens cursor)
      (if (cursor-end? cursor)
          (fail)
          (let ((result (regexp-exec rx (cursor-text cursor)
                                     (cursor-position cursor))))
            (if result
                (let ((str (match:substring result 0)))
                  (values (token-add tokens str)
                          (move-cursor-by cursor (string-length str))))
                (fail)))))))

(define (lex-string str)
  "Return a lexer that succeeds with STR when the input starts with
STR."
  (lambda (tokens cursor)
    (if (string-prefix?* str (cursor-text cursor) (cursor-position cursor))
        (values (token-add tokens str)
                (move-cursor-by cursor (string-length str)))
        (fail))))

(define (lex-char-set char-set)
  "Return a lexer that succeeds with the nonempty input prefix that
matches CHAR-SET, or fails if the first input character does not
belong to CHAR-SET."
  (define (char-set-substring str start)
    (let ((len (string-length str)))
      (let loop ((index start))
        (cond
         ((>= index len)
          (substring str start len))
         ((char-set-contains? char-set (string-ref str index))
          (loop (1+ index)))
         (else
          (substring str start index))))))

  (lambda (tokens cursor)
    (match (char-set-substring (cursor-text cursor) (cursor-position cursor))
      ("" (fail))
      (str
       (values (token-add tokens str)
               (move-cursor-by cursor (string-length str)))))))

(define lex-whitespace
  (lex-char-set char-set:whitespace))

(define* (lex-delimited open #:key (until open) (escape #\\) nested?)
  "Return a lexer that succeeds with the string delimited by the
opening string OPEN and the closing string UNTIL.  Characters within
the delimited expression may be escaped with the character ESCAPE.  If
NESTED?, allow for delimited expressions to be arbitrarily nested
within."
  (define (delimit str start)
    (let ((len (string-length str)))
      (let loop ((index start))
        (cond
         ;; Out of bounds.
         ((>= index len)
          len)
         ;; Escape character.
         ((eqv? escape (string-ref str index))
          (loop (+ index 2)))
         ;; Closing delimiter.
         ((string-prefix?* until str index)
          (+ index (string-length until)))
         ;; Nested delimited string.
         ((and nested? (string-prefix?* open str index))
          (loop (delimit str (+ index (string-length open)))))
         (else
          (loop (1+ index)))))))

  (lambda (tokens cursor)
    (let ((str (cursor-text cursor))
          (pos (cursor-position cursor)))
      (if (string-prefix?* open str pos)
          (let ((end (delimit str (+ pos (string-length open)))))
            (values (token-add tokens (substring str pos end))
                    (move-cursor cursor end)))
          (fail)))))

(define (lex-tag tag lexer)
  "Transform the head element of the tokens queue returned by LEXER
into a two element list consisting of the symbol TAG and the element
itself."
  (lambda (tokens cursor)
    (let-values (((result remainder) (lexer tokens cursor)))
      (if result
          (values (token-add (token-drop result 1)
                             (list tag (token-peek result)))
                  remainder)
          (fail)))))
