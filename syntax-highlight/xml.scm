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

(define-module (syntax-highlight xml)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-11)
  #:use-module (srfi srfi-41)
  #:use-module (syntax-highlight lexers)
  #:export (lex-xml))

(define char-set:not-whitespace
  (char-set-complement char-set:whitespace))

(define char-set:xml-symbol
  (char-set-union char-set:letter+digit
                  (char-set #\. #\- #\_ #\:)))

(define lex-comment
  (lex-tag 'comment (lex-delimited "<!--" #:until "-->")))

(define lex-xml-symbol
  (lex-char-set char-set:xml-symbol))

(define lex-element-name
  (lex-tag 'element lex-xml-symbol))

(define lex-whitespace-maybe
  (lex-maybe lex-whitespace))

(define lex-attribute
  (lex-all (lex-tag 'attribute lex-xml-symbol)
           lex-whitespace-maybe
           (lex-string "=")
           lex-whitespace-maybe
           (lex-tag 'string (lex-delimited "\""))))

(define lex-open-tag
  (lex-all (lex-tag 'open (lex-any (lex-string "<?")
                                   (lex-string "<")))
           lex-element-name
           (lex-zero-or-more
            (lex-any (lex-all lex-whitespace
                              lex-attribute)
                     lex-whitespace))
           (lex-tag 'close (lex-any (lex-string ">")
                                    (lex-string "/>")
                                    (lex-string "?>")))))

(define lex-close-tag
  (lex-all (lex-tag 'open (lex-string "</"))
           lex-element-name
           (lex-tag 'close (lex-string ">"))))

(define lex-entity
  (lex-tag 'entity (lex-delimited "&" #:until ";")))

(define lex-text
  (lex-char-set (char-set-difference char-set:full
                                     (char-set #\< #\&))))

(define lex-whitespace-maybe
  (lex-maybe lex-whitespace))

(define lex-xml-element
  (lex-tag 'element lex-xml-symbol))

(define lex-xml-attribute
  (lex-all (lex-tag 'attribute lex-xml-symbol)
           lex-whitespace-maybe
           (lex-string "=")
           lex-whitespace-maybe
           (lex-tag 'string (lex-delimited "\""))))

(define lex-xml
  (lex-consume
   (lex-any lex-comment
            lex-close-tag
            lex-open-tag
            lex-entity
            lex-text)))

(lex-xml empty-tokens (string->cursor "<foo bar=\"baz\">quux &copy; </foo>"))
