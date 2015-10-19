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
  #:use-module (syntax-highlight parsers)
  #:export (xml-highlighter))

(define (flatten+compact highlights)
  (define tagged?
    (match-lambda
      (((? symbol?) _) #t)
      (_ #f)))

  (let loop ((highlights highlights)
             (result '()))
    (match highlights
      (() (reverse result))
      (("" . tail)
       (loop tail result))
      (((or (? string? head) (? tagged? head)) . tail)
       (loop tail (cons head result)))
      ((head . tail)
       (loop tail (append (reverse (flatten+compact head)) result))))))

(define parse-comment
  (tagged-parser 'comment (parse-delimited "<!--" #:until "-->")))

(define parse-xml-symbol
  (parse-char-set
   (char-set-union char-set:letter+digit
                   (char-set #\. #\- #\_ #\:))))

(define parse-element-name
  (tagged-parser 'element parse-xml-symbol))

(define parse-whitespace-maybe
  (parse-maybe parse-whitespace))

(define parse-attribute
  (parse-each (tagged-parser 'attribute parse-xml-symbol)
              parse-whitespace-maybe
              (parse-string "=")
              parse-whitespace-maybe
              (tagged-parser 'string (parse-delimited "\""))))

(define parse-open-tag
  (parse-each (tagged-parser 'open (parse-any (parse-string "<?")
                                              (parse-string "<")))
              parse-element-name
              (parse-many
               (parse-any (parse-each
                           parse-whitespace
                           parse-attribute)
                          parse-whitespace))
              (tagged-parser 'close (parse-any (parse-string ">")
                                               (parse-string "/>")
                                               (parse-string "?>")))))

(define parse-close-tag
  (parse-each (tagged-parser 'open (parse-string "</"))
              parse-element-name
              (tagged-parser 'close (parse-string ">"))))

(define char-set:not-whitespace
  (char-set-complement char-set:whitespace))

(define parse-tag
  (parse-each (parse-string "<")
              (parse-char-set
               (char-set-delete char-set:not-whitespace #\>))
              (parse-string ">")))

(define parse-entity
  (tagged-parser 'entity (parse-delimited "&" #:until ";")))

(define parse-text
  (parse-char-set
   (char-set-difference char-set:full (char-set #\<))))

(define xml-highlighter
  (parse-map flatten+compact
             (parse-many
              (parse-any parse-comment
                         parse-open-tag
                         parse-close-tag
                         parse-entity
                         parse-text))))
