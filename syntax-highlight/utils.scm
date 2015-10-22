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
;; Utility procedures.
;;
;;; Code:

(define-module (syntax-highlight utils)
  #:use-module (srfi srfi-41)
  #:export (string->stream
            stream->string))

(define (string->stream str)
  "Convert the string STR into a stream of characters."
  (stream-map (lambda (i)
                (string-ref str i))
              (stream-range 0 (string-length str))))

(define (stream->string stream)
  "Convert STREAM, a SRFI-41 stream of characters, into a string."
  (list->string (stream->list stream)))
