;;; guile-syntax-highlight --- General-purpose syntax highlighter
;;; Copyright © 2021 Julien Lepiller <julien@lepiller.eu>
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
;; Syntax highlighting for css files.
;; See https://www.w3.org/TR/css-syntax-3
;;
;;; Code:

(define-module (syntax-highlight css)
  #:use-module (ice-9 match)
  #:use-module (syntax-highlight lexers)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-11)
  #:use-module (srfi srfi-26)
  #:export (lex-css))

;; From various documents
(define %css-functions
  '(;; https://www.w3.org/TR/css-transforms-1/
    "translate" "scale" "rotate" "skewX" "skewY" "matrix" "translateX"
    "translateY" "scaleX" "scaleY" "skew" "translate3d"
    ;; https://www.w3.org/TR/css-values-3/
    "calc" "attr"
    ;; https://www.w3.org/TR/css-variables-1/
    "var"
    ;; https://www.w3.org/TR/css-color-3/
    "rgb" "rgba" "hsl" "hsla"
    ;; https://www.w3.org/TR/css-color-4/
    "color" "lch" "hwb" "lab"
    ;; https://www.w3.org/TR/css-images-3/
    "linear-gradient" "radial-gradient" "repeating-linear-gradient"
    "repeating-radial-gradient"
    ;; https://www.w3.org/TR/css-easing-1/
    "cubic-bezier" "steps"))

(define %css-vendor-prefixes
  ;; from https://www.w3.org/TR/CSS2/syndata.html#vendor-keywords
  '("-ms-" "mso-" "-moz-" "-o-" "-xv-" "-atsc-" "-khtml-" "-webkit-"
    "prince-" "-ah-" "-hp-" "-ro-" "-rim-" "-tc-"))

;; from https://www.w3.org/Style/CSS/all-properties.en.html
(define %css-properties
  '("accent-color" "align-content" "align-items" "align-self"
    "alignment-baseline" "all" "animation" "animation-delay"
    "animation-direction" "animation-duration" "animation-fill-mode"
    "animation-iteration-count" "animation-name" "animation-play-state"
    "animation-timing-function" "appearance" "aspect-ratio" "azimuth"
    "backface-visibility" "background" "background-attachment"
    "background-blend-mode" "background-clip" "background-color"
    "background-image" "background-origin" "background-position"
    "background-repeat" "background-size" "baseline-shift" "baseline-source"
    "block-ellipsis" "block-size" "block-step" "block-step-align"
    "block-step-insert" "block-step-round" "block-step-size" "bookmark-label"
    "bookmark-level" "bookmark-state" "border" "border-block"
    "border-block-color" "border-block-end" "border-block-end-color"
    "border-block-end-style" "border-block-end-width" "border-block-start"
    "border-block-start-color" "border-block-start-style"
    "border-block-start-width" "border-block-style" "border-block-width"
    "border-bottom" "border-bottom-color" "border-bottom-left-radius"
    "border-bottom-right-radius" "border-bottom-style" "border-bottom-width"
    "border-boundary" "border-collapse" "border-color" "border-end-end-radius"
    "border-end-start-radius" "border-image" "border-image-outset"
    "border-image-repeat" "border-image-slice" "border-image-source"
    "border-image-width" "border-inline" "border-inline-color"
    "border-inline-end" "border-inline-end-color" "border-inline-end-style"
    "border-inline-end-width" "border-inline-start" "border-inline-start-color"
    "border-inline-start-style" "border-inline-start-width" "border-inline-style"
    "border-inline-width" "border-left" "border-left-color" "border-left-style"
    "border-left-width" "border-radius" "border-right" "border-right-color"
    "border-right-style" "border-right-width" "border-spacing"
    "border-start-end-radius" "border-start-start-radius" "border-style"
    "border-top" "border-top-color" "border-top-left-radius"
    "border-top-right-radius" "border-top-style" "border-top-width"
    "border-width" "bottom" "box-decoration-break" "box-shadow" "box-sizing"
    "box-snap" "break-after" "break-before" "break-inside" "caption-side" "caret"
    "caret-color" "caret-shape" "chains" "clear" "clip" "clip-path" "clip-rule"
    "color" "color-adjust" "color-interpolation-filters" "color-scheme"
    "column-count" "column-fill" "column-gap" "column-rule" "column-rule-color"
    "column-rule-style" "column-rule-width" "column-span" "column-width" "columns"
    "contain" "contain-intrinsic-block-size" "contain-intrinsic-height"
    "contain-intrinsic-inline-size" "contain-intrinsic-size"
    "contain-intrinsic-width" "content" "content-visibility" "continue"
    "counter-increment" "counter-reset" "counter-set" "cue" "cue-after"
    "cue-before" "cursor" "direction" "display" "dominant-baseline" "elevation"
    "empty-cells" "fill" "fill-break" "fill-color" "fill-image" "fill-opacity"
    "fill-origin" "fill-position" "fill-repeat" "fill-rule" "fill-size" "filter"
    "flex" "flex-basis" "flex-direction" "flex-flow" "flex-grow" "flex-shrink"
    "flex-wrap" "float" "float-defer" "float-offset" "float-reference"
    "flood-color" "flood-opacity" "flow" "flow-from" "flow-into" "font"
    "font-family" "font-feature-settings" "font-kerning" "font-language-override"
    "font-optical-sizing" "font-palette" "font-size" "font-size-adjust"
    "font-stretch" "font-style" "font-synthesis" "font-synthesis-small-caps"
    "font-synthesis-style" "font-synthesis-weight" "font-variant"
    "font-variant-alternates" "font-variant-caps" "font-variant-east-asian"
    "font-variant-emoji" "font-variant-ligatures" "font-variant-numeric"
    "font-variant-position" "font-variation-settings" "font-weight"
    "footnote-display" "footnote-policy" "forced-color-adjust" "gap"
    "glyph-orientation-vertical" "grid" "grid-area" "grid-auto-columns"
    "grid-auto-flow" "grid-auto-rows" "grid-column" "grid-column-end"
    "grid-column-start" "grid-row" "grid-row-end" "grid-row-start" "grid-template"
    "grid-template-areas" "grid-template-columns" "grid-template-rows"
    "hanging-punctuation" "height" "hyphenate-character" "hyphenate-limit-chars"
    "hyphenate-limit-last" "hyphenate-limit-lines" "hyphenate-limit-zone"
    "hyphens" "image-orientation" "image-rendering" "image-resolution"
    "initial-letter" "initial-letter-align" "initial-letter-wrap" "inline-size"
    "inline-sizing" "input-security" "inset" "inset-block" "inset-block-end"
    "inset-block-start" "inset-inline" "inset-inline-end" "inset-inline-start"
    "isolation" "justify-content" "justify-items" "justify-self" "leading-trim"
    "left" "letter-spacing" "lighting-color" "line-break" "line-clamp"
    "line-grid" "line-height" "line-height-step" "line-padding" "line-snap"
    "list-style" "list-style-image" "list-style-position" "list-style-type"
    "margin" "margin-block" "margin-block-end" "margin-block-start"
    "margin-bottom" "margin-break" "margin-inline" "margin-inline-end"
    "margin-inline-start" "margin-left" "margin-right" "margin-top" "margin-trim"
    "marker" "marker-end" "marker-knockout-left" "marker-knockout-right"
    "marker-mid" "marker-pattern" "marker-segment" "marker-side" "marker-start"
    "mask" "mask-border" "mask-border-mode" "mask-border-outset"
    "mask-border-repeat" "mask-border-slice" "mask-border-source"
    "mask-border-width" "mask-clip" "mask-composite" "mask-image" "mask-mode"
    "mask-origin" "mask-position" "mask-repeat" "mask-size" "mask-type"
    "max-block-size" "max-height" "max-inline-size" "max-lines" "max-width"
    "min-block-size" "min-height" "min-inline-size" "min-intrinsic-sizing"
    "min-width" "mix-blend-mode" "nav-down" "nav-left" "nav-right" "nav-up"
    "object-fit" "object-position" "offset" "offset-anchor" "offset-distance"
    "offset-path" "offset-position" "offset-rotate" "opacity" "order" "orphans"
    "outline" "outline-color" "outline-offset" "outline-style" "outline-width"
    "overflow" "overflow-anchor" "overflow-block" "overflow-clip-margin"
    "overflow-inline" "overflow-wrap" "overflow-x" "overflow-y"
    "overscroll-behavior" "overscroll-behavior-block" "overscroll-behavior-inline"
    "overscroll-behavior-x" "overscroll-behavior-y" "padding" "padding-block"
    "padding-block-end" "padding-block-start" "padding-bottom" "padding-inline"
    "padding-inline-end" "padding-inline-start" "padding-left" "padding-right"
    "padding-top" "page" "page-break-after" "page-break-before" "page-break-inside"
    "pause" "pause-after" "pause-before" "perspective" "perspective-origin" "pitch"
    "pitch-range" "place-content" "place-items" "place-self" "play-during"
    "position" "print-color-adjust" "property-name" "quotes" "region-fragment"
    "resize" "rest" "rest-after" "rest-before" "richness" "right" "rotate"
    "row-gap" "ruby-align" "ruby-merge" "ruby-overhang" "ruby-position" "running"
    "scale" "scroll-behavior" "scroll-margin" "scroll-margin-block"
    "scroll-margin-block-end" "scroll-margin-block-start" "scroll-margin-bottom"
    "scroll-margin-inline" "scroll-margin-inline-end" "scroll-margin-inline-start"
    "scroll-margin-left" "scroll-margin-right" "scroll-margin-top" "scroll-padding"
    "scroll-padding-block" "scroll-padding-block-end" "scroll-padding-block-start"
    "scroll-padding-bottom" "scroll-padding-inline" "scroll-padding-inline-end"
    "scroll-padding-inline-start" "scroll-padding-left" "scroll-padding-right"
    "scroll-padding-top" "scroll-snap-align" "scroll-snap-stop" "scroll-snap-type"
    "scrollbar-color" "scrollbar-gutter" "scrollbar-width" "shape-image-threshold"
    "shape-inside" "shape-margin" "shape-outside" "spatial-navigation-action"
    "spatial-navigation-contain" "spatial-navigation-function" "speak" "speak-as"
    "speak-header" "speak-numeral" "speak-punctuation" "speech-rate" "stress"
    "string-set" "stroke" "stroke-align" "stroke-alignment" "stroke-break"
    "stroke-color" "stroke-dash-corner" "stroke-dash-justify" "stroke-dashadjust"
    "stroke-dasharray" "stroke-dashcorner" "stroke-dashoffset" "stroke-image"
    "stroke-linecap" "stroke-linejoin" "stroke-miterlimit" "stroke-opacity"
    "stroke-origin" "stroke-position" "stroke-repeat" "stroke-size" "stroke-width"
    "tab-size" "table-layout" "text-align" "text-align-all" "text-align-last"
    "text-combine-upright" "text-decoration" "text-decoration-color"
    "text-decoration-line" "text-decoration-skip" "text-decoration-skip-box"
    "text-decoration-skip-ink" "text-decoration-skip-inset"
    "text-decoration-skip-self" "text-decoration-skip-spaces"
    "text-decoration-style" "text-decoration-thickness" "text-edge" "text-emphasis"
    "text-emphasis-color" "text-emphasis-position" "text-emphasis-skip"
    "text-emphasis-style" "text-group-align" "text-indent" "text-justify"
    "text-orientation" "text-overflow" "text-shadow" "text-space-collapse"
    "text-space-trim" "text-spacing" "text-transform" "text-underline-offset"
    "text-underline-position" "text-wrap" "top" "transform" "transform-box"
    "transform-origin" "transform-style" "transition" "transition-delay"
    "transition-duration" "transition-property" "transition-timing-function"
    "translate" "unicode-bidi" "user-select" "vertical-align" "visibility"
    "voice-balance" "voice-duration" "voice-family" "voice-pitch" "voice-range"
    "voice-rate" "voice-stress" "voice-volume" "volume" "white-space" "widows"
    "width" "will-change" "word-boundary-detection" "word-boundary-expansion"
    "word-break" "word-spacing" "word-wrap" "wrap-after" "wrap-before" "wrap-flow"
    "wrap-inside" "wrap-through" "writing-mode" "z-index"
    ;; Descriptors, not really properties, but they look like properties
    ;; https://www.w3.org/Style/CSS/all-descriptors
    "additive-symbols" "any-hover" "any-pointer" "ascent-override" "aspect-ratio"
    "base-palette" "bleed" "color" "color-gamut" "color-index" "components"
    "descent-override" "device-aspect-ratio" "device-height" "device-width"
    "display-mode" "dynamic-range" "environment-blending" "fallback" "font-display"
    "font-family" "font-feature-settings" "font-language-override"
    "font-named-instance" "font-size" "font-stretch" "font-style"
    "font-variation-settings" "font-weight" "forced-colors" "grid" "height"
    "hover" "inherits" "initial-value" "inverted-colors" "line-gap-override"
    "marks" "max-height" "max-width" "max-zoom" "min-height" "min-width"
    "min-zoom" "monochrome" "negative" "orientation" "overflow-block"
    "overflow-inline" "override-color" "pad" "pointer" "prefers-color-scheme"
    "prefers-contrast" "prefers-reduced-data" "prefers-reduced-motion"
    "prefers-reduced-transparency" "prefix" "range" "rendering-intent"
    "resolution" "scan" "scripting" "shape" "size" "size-adjust" "speak-as" "src"
    "subscript-position-override" "subscript-size-override" "suffix"
    "superscript-position-override" "superscript-size-override" "symbols"
    "syntax" "system" "unicode-range" "update" "user-zoom" "video-color-gamut"
    "video-dynamic-range" "video-height" "video-resolution" "video-width"
    "viewport-fit" "width" "zoom"))

(define %prefixed-properties
  (apply append
         %css-properties
         (map
           (lambda (prefix)
             (map
               (lambda (property)
                 (string-append prefix property))
               %css-properties))
           %css-vendor-prefixes)))

(define %css-keyword-values
  '("inherit" "auto" "initial" "unset"
    ;; https://www.w3.org/TR/css-color-3
    "transparent" "aliceblue" "antiquewhite" "aqua" "aquamarine" "azure" "beige"
    "bisque" "black" "blanchedalmond" "blue" "blueviolet" "brown" "burlywood"
    "cadetblue" "chartreuse" "chocolate" "coral" "cornflowerblue" "cornsilk"
    "crimson" "cyan" "darkblue" "darkcyan" "darkgoldenrod" "darkgray" "darkgreen"
    "darkgrey" "darkkhaki" "darkmagenta" "darkolivegreen" "darkorange" "darkorchid"
    "darkred" "darksalmon" "darkseagreen" "darkslateblue" "darkslategray"
    "darkslategrey" "darkturquoise" "darkviolet" "deeppink" "deepskyblue"
    "dimgray" "dimgrey" "dodgerblue" "firebrick" "floralwhite" "forestgreen"
    "fuchsia" "gainsboro" "ghostwhite" "gold" "goldenrod" "gray" "green"
    "greenyellow" "grey" "honeydew" "hotpink" "indianred" "indigo" "ivory"
    "khaki" "lavender" "lavenderblush" "lawngreen" "lemonchiffon" "lightblue"
    "lightcoral" "lightcyan" "lightgoldenrodyellow" "lightgray" "lightgreen"
    "lightgrey" "lightpink" "lightsalmon" "lightseagreen" "lightskyblue"
    "lightslategray" "lightslategrey" "lightsteelblue" "lightyellow" "lime"
    "limegreen" "linen" "magenta" "maroon" "mediumaquamarine" "mediumblue"
    "mediumorchid" "mediumpurple" "mediumseagreen" "mediumslateblue"
    "mediumspringgreen" "mediumturquoise" "mediumvioletred" "midnightblue"
    "mintcream" "mistyrose" "moccasin" "navajowhite" "navy" "oldlace" "olive"
    "olivedrab" "orange" "orangered" "orchid" "palegoldenrod" "palegreen"
    "paleturquoise" "palevioletred" "papayawhip" "peachpuff" "peru" "pink"
    "plum" "powderblue" "purple" "red" "rosybrown" "royalblue" "saddlebrown"
    "salmon" "sandybrown" "seagreen" "seashell" "sienna" "silver" "skyblue"
    "slateblue" "slategray" "slategrey" "snow" "springgreen" "steelblue"
    "tan" "teal" "thistle" "tomato" "turquoise" "violet" "wheat" "white"
    "whitesmoke" "yellow" "yellowgreen" "currentColor"
    ;; deprecated in css 3
    "ActiveBorder" "ActiveCaption" "AppWorkspace" "Background" "ButtonFace"
    "ButtonHighlight" "ButtonShadow" "ButtonText" "CaptionText" "GrayText"
    "Highlight" "HighlightText" "InactiveBorder" "InactiveCaption" "InactiveCaptionText"
    "InfoBackground" "InfoText" "Menu" "MenuText" "Scrollbar" "ThreeDDarkShadow"
    "ThreeDFace" "ThreeDHighlight" "ThreeDLightShadow" "ThreeDShadow" "Window"
    "WindowFrame" "WindowText"
    ;; https://www.w3.org/TR/css-backgrounds-3
    "repeat" "repeat-x" "repeat-y" "space" "round" "no-repeat" "scroll" "fixed"
    "local" "left" "center" "right" "top" "bottom" "border-box" "content-box"
    "padding-box" "contain" "cover"
    "none" "hidden" "dotted" "dashed" "solid" "double" "groove" "ridge" "inset"
    "outset"
    ;; https://www.w3.org/TR/css-images-3
    "fill" "scale-down" "from-image" "flip" "smooth" "high-quality" "crisp-edges"
    "pixelated"
    ;; https://www.w3.org/TR/css-fonts-3
    "normal" "bold" "bolder" "lighter" "ultra-condensed" "extra-condensed"
    "condensed" "semi-condensed" "semi-expanded" "expanded" "extra-expanded"
    "ultra-expanded" "italic" "oblique" "xx-small" "x-small" "small" "medium"
    "large" "x-large" "xx-large" "larger" "smaller" "small-caps" "caption"
    "icon" "menu" "message-box" "small-caption" "status-bar"
    ;; https://www.w3.org/TR/css-writing-modes-3
    "ltr" "rtl" "embed" "isolate" "bidi-override" "isolate-override" "plaintext"
    "horizontal-tb" "vertical-rl" "vertical-lr" "mixed" "upright" "sideways"
    ;; https://www.w3.org/TR/css-multicol-1
    "balance" "balance-all"
    ;; https://www.w3.org/TR/css-flexbox-1
    "row" "row-reverse" "column" "column-reverse" "nowrap" "wrap" "wrap-reverse"
    "content" "flex-start" "flex-end" "center" "space-between" "space-around"
    "baseline" "stretch"
    ;; https://www.w3.org/TR/css-ui-3
    "content-box" "border-box" "both" "horizontal" "vertical" "clip" "ellipsis"
    "default" "context-menu" "help" "pointer" "progress" "wait" "cell"
    "crosshair" "text" "vertical-text" "alias" "copy" "move" "no-drop"
    "not-allowed" "grab" "grabbing" "e-resize" "n-resize" "ne-resize"
    "nw-resize" "s-resize" "se-resize" "sw-resize" "w-resize" "ew-resize"
    "ns-resize" "nesw-resize" "nwse-resize" "col-resize" "row-resize"
    "all-scroll" "zoom-in" "zoom-out"
    ;; https://www.w3.org/TR/css-contain-1
    "strict" "content" "size" "layout" "paint"
    ;; https://www.w3.org/TR/css-transforms-1
    "content-box" "border-box" "fill-box" "stroke-box" "view-box"
    ;; https://www.w3.org/TR/compositing-1
    "multiply" "screen" "overlay" "darken" "lighten" "color-dodge" "color-burn"
    "hard-light" "soft-light" "difference" "exclusion" "hue" "saturation" "color"
    "luminosity" "isolate"
    ;; https://www.w3.org/TR/css-easing-1
    "linear" "ease" "ease-in" "ease-out" "ease-in-out" "step-start" "step-end"
    ;; ??
    "inline" "flex" "inline-block" "block" "table" "table-row" "table-cell"
    "thin"
    "relative" "absolute"
    "start" "left" "right" "center" "justify"
    ))

(define %css-units
  '("dpi" "dpcm" "dppx" "%" "em" "ex" "ch" "rem" "vw" "vh" "vmin" "vmax" "cm"
    "mm" "Q" "in" "pt" "pc" "px" "deg" "rad" "grad" "turn" "s" "ms" "Hz" "kHz"))

(define lex-escape
  (lex-all (lex-string "\\")
           (lex-any
             (lex-char-set (string->char-set "0123456789abcdefABCDEF") #:max 6)
             (lex-char (char-set-complement (char-set #\newline))))))

(define lex-color
  (lex-group
    (lex-all (lex-string "#")
             (lex-char-set (string->char-set "0123456789abcdefABCDEF")))))

(define ident-char-set
  (char-set-union
    (char-set #\_)
    char-set:letter))
(define ident-rest-char-set
  (char-set-union
    (char-set #\_ #\-)
    char-set:letter+digit))

(define lex-ident
  (lex-group
    (lex-all
      (lex-any
        (lex-string "--")
        (lex-all
          (lex-maybe (lex-string "-"))
          (lex-any
            lex-escape
            (lex-char ident-char-set))))
      (lex-zero-or-more
        (lex-any
          lex-escape
          (lex-char-set ident-rest-char-set))))))

(define lex-double-string
  (lex-all
    (lex-string "\"")
    (lex-zero-or-more
      (lex-any
        (lex-char-set (char-set-complement (char-set #\\ #\" #\newline)))
        lex-escape
        (lex-string "\\\n")))
    (lex-string "\"")))

(define lex-single-string
  (lex-all
    (lex-string "'")
    (lex-zero-or-more
      (lex-any
        (lex-char-set (char-set-complement (char-set #\\ #\' #\newline)))
        lex-escape
        (lex-string "\\\n")))
    (lex-string "'")))

(define lex-number
  (lex-group
    (lex-all
      (lex-maybe
        (lex-any (lex-string "-") (lex-string "+")))
      (lex-char-set char-set:digit)
      (lex-maybe (lex-string "."))
      (lex-maybe (lex-char-set char-set:digit))
      (lex-maybe
        (lex-all
          (lex-any (lex-string "e") (lex-string "E"))
          (lex-maybe
            (lex-any (lex-string "-") (lex-string "+")))
          (lex-char-set char-set:digit))))))

(define lex-ws
  (lex-any (lex-tag 'comment (lex-delimited "/*" #:until "*/"))
           (lex-char-set char-set:whitespace)))

(define lex-token
  (lex-any
    (lex-tag 'comment (lex-delimited "/*" #:until "*/"))
    (lex-char-set char-set:whitespace)
    (lex-tag 'string (lex-group lex-double-string))
    (lex-tag 'string (lex-group lex-single-string))
    (lex-tag 'id (lex-group (lex-all (lex-string "#")
                                     lex-ident)))
    (lex-tag 'open (lex-string "("))
    (lex-tag 'close (lex-string ")"))
    (lex-tag 'open (lex-string "{"))
    (lex-tag 'close (lex-string "}"))
    (lex-tag 'open (lex-string "["))
    (lex-tag 'close (lex-string "]"))
    (lex-tag 'number (lex-group
                       (lex-all
                         lex-number
                         (lex-maybe
                           (lex-any
                             (lex-filter (lambda (str)
                                           (any (cut string=? <> str)
                                                %css-units))
                                         lex-ident)
                             (lex-string "%"))))))
    (lex-tag 'comma (lex-string ","))
    (lex-tag 'cdc (lex-string "-->"))
    (lex-tag 'colon (lex-string ":"))
    (lex-tag 'semi (lex-string ";"))
    (lex-tag 'cdo (lex-string "<!--"))
    (lex-tag 'keyword
              (lex-group
                (lex-all
                  (lex-string "@")
                  lex-ident)))
    (lex-tag 'ident lex-ident)
    (lex-char char-set:full)))

(define (lex-css-single)
  (define function-lexer
    (lex-all
      (lex-any
        (lex-tag 'builtin
                 (lex-filter (lambda (str)
                               (any (cut string=? <> str)
                                    %css-functions))
                             lex-ident))
        (lex-tag 'function lex-ident))
      (lex-tag 'open (lex-string "("))
      (lex-consume-until (lex-tag 'close (lex-string ")"))
        (lex-component-value 'function))))
  (define (lex-function tokens cursor)
    (function-lexer tokens cursor))

  (define (lex-definition position)
    (lex-all
      (lex-any
        (lex-tag 'builtin-property
                 (lex-filter (lambda (str)
                               (any (cut string=? <> str)
                                    %prefixed-properties))
                             lex-ident))
        (lex-tag 'property lex-ident))
      (lex-zero-or-more lex-ws)
      (lex-string ":")
      (lex-zero-or-more lex-ws)
      (lex-consume-until (lex-any
                           (lex-tag 'comma (lex-string ";"))
                           (lex-peek (lex-string (match position
                                                   ('curly "}")
                                                   ('rule "}")
                                                   ('paren ")")))))
        (lex-component-value 'value))))

  (define (lex-component-value position)
    (lex-any
      lex-ws
      lex-block
      lex-function
      (match position
        ('curly
         (lex-any
           lex-rule
           (lex-definition position)))
        ((or 'rule 'paren)
         (lex-definition position))
        ('prelude
         (lex-any
                    (lex-tag 'class (lex-group (lex-all (lex-string ".") lex-ident)))
                    (lex-all
                      (lex-tag 'selector (lex-group (lex-all (lex-string ":") lex-ident)))
                      (lex-maybe
                        (lex-all
                          (lex-tag 'open (lex-string "("))
                          (lex-consume-until (lex-tag 'close (lex-string ")"))
                            lex-prelude-component-value))))
                    (lex-tag 'prelude lex-ident)
                    (lex-string ">")
                    (lex-string "*")))
        ('value (lex-any
                  (lex-tag 'color lex-color)
                  (lex-tag 'important (lex-string "!important"))
                  (lex-tag 'keyword
                           (lex-filter (lambda (str)
                                         (any (cut string=? <> str)
                                              %css-keyword-values))
                                       lex-ident))))
        ;; function, square, paren
        (_ lex-fail))
      lex-token))
  (define (lex-prelude-component-value tokens cursor)
    ((lex-component-value 'prelude) tokens cursor))

  (define rule-block-lexer
    (lex-all
      (lex-tag 'open (lex-string "{"))
      (lex-consume-until (lex-tag 'close (lex-string "}"))
        (lex-component-value 'rule))))
  (define (lex-rule-block tokens cursor)
    (rule-block-lexer tokens cursor))

  (define curly-block-lexer
    (lex-all
      (lex-tag 'open (lex-string "{"))
      (lex-consume-until (lex-tag 'close (lex-string "}"))
        (lex-component-value 'curly))))
  (define (lex-curly-block tokens cursor)
    (curly-block-lexer tokens cursor))

  (define square-block-lexer
    (lex-all
      (lex-tag 'open (lex-string "["))
      (lex-consume-until (lex-tag 'close (lex-string "]"))
        (lex-component-value 'square))))
  (define (lex-square-block tokens cursor)
    (square-block-lexer tokens cursor))

  (define par-block-lexer
    (lex-all
      (lex-tag 'open (lex-string "("))
      (lex-consume-until (lex-tag 'close (lex-string ")"))
        (lex-component-value 'paren))))
  (define (lex-par-block tokens cursor)
    (par-block-lexer tokens cursor))

  (define block-lexer
    (lex-any
      lex-curly-block
      lex-square-block
      lex-par-block))
  (define (lex-block tokens cursor)
    (block-lexer tokens cursor))

  (define at-rule-lexer
    (lex-all (lex-tag 'keyword (lex-group (lex-all (lex-string "@") lex-ident)))
             (lex-consume-until
               (lex-any (lex-tag 'semi (lex-string ";"))
                        lex-curly-block)
               (lex-any
                 lex-block
                 lex-at-rule
                 lex-token))))
  (define (lex-at-rule tokens cursor)
    (at-rule-lexer tokens cursor))

  (define rule-lexer
    (lex-consume-until
      lex-rule-block
      (lex-component-value 'prelude)))
  (define (lex-rule tokens cursor)
    (rule-lexer tokens cursor))

  (lex-any
    lex-ws
    lex-at-rule
    lex-rule))

(define lex-css
  (lex-consume (lex-css-single)))
