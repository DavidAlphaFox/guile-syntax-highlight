;;; guile-syntax-highlight -- General-purpose syntax highlighter
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
;; General-purpose syntax highlighting framework.
;;
;;; Code:

(define-module (syntax-highlight)
  #:use-module (ice-9 match)
  #:use-module (ice-9 rdelim)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-11)
  #:use-module (srfi srfi-26)
  #:use-module (syntax-highlight lexers)
  #:export (highlight
            highlights->sxml))

(define (object->string obj)
  (cond
   ((input-port? obj)
    (read-string obj))
   ((string? obj)
    obj)
   (else
    (error "not an input port or string: "
           obj))))

(define object->cursor
  (compose string->cursor object->string))

(define* (highlight lexer #:optional (string-or-port (current-input-port)))
  "Apply LEXER to STRING-OR-PORT, a string or an open input port.  If
STRING-OR-PORT is not specified, characters are read from the current
input port."
  (let-values (((result remainder)
                (lexer empty-tokens (object->cursor string-or-port))))
    (and result (tokens->list result))))

(define (highlights->sxml highlights)
  "Convert HIGHLIGHTS, a list of syntax highlighting expressions, into
a list of SXML 'span' nodes.  Each 'span' node has a 'class' attribute
corresponding to the highlighting tag name."
  (define (tag->class tag)
    (string-append "syntax-" (symbol->string tag)))

  (map (match-lambda
         ((? string? str) str)
         ((content ...)
          (let loop ((tags '()) (text "") (content content))
            (match content
             (() `(span (@ (class ,(string-join (map tag->class tags) " "))) ,text))
             (((? symbol? tag) content ...)
              (loop (cons tag tags) text content))
             (((? string? s) content ...)
              (loop tags (string-append text s) content))))))
       highlights))
