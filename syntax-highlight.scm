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
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-11)
  #:use-module (srfi srfi-26)
  #:use-module (srfi srfi-41)
  #:export (highlight
            highlights->sxml))

(define (string->stream str)
  "Convert the string STR into a stream of characters."
  (stream-map (lambda (i)
                (string-ref str i))
              (stream-range 0 (string-length str))))

(define* (highlight highlighter #:optional (stream (current-input-port)))
  "Apply HIGHLIGHTER, a syntax highlighting procedure, to STREAM.
STREAM may be an open port, string, or SRFI-41 character stream.  If
STREAM is not specified, characters are read from the current input
port."
  (let-values (((result stream)
                (highlighter (cond
                              ((port? stream)
                               (port->stream stream))
                              ((string? stream)
                               (string->stream stream))
                              ((stream? stream)
                               stream)
                              (else
                               (error "Cannot convert to stream: " stream))))))
    result))

(define (highlights->sxml highlights)
  "Convert HIGHLIGHTS, a list of syntax highlighting expressions, into
a list of SXML 'span' nodes.  Each 'span' node has a 'class' attribute
corresponding to the highlighting tag name."
  (define (tag->class tag)
    (string-append "syntax-" (symbol->string tag)))

  (map (match-lambda
         ((? string? str) str)
         ((tag text)
          `(span (@ (class ,(tag->class tag))) ,text)))
       highlights))
