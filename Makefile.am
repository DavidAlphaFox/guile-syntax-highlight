# guile-syntax-highlight --- General-purpose syntax highlighter
# Copyright © 2015 David Thompson <davet@gnu.org>
#
# Guile-syntax-highlight is free software; you can redistribute it
# and/or modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# Guile-syntax-highlight is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with guile-syntax-highlight.  If not, see
# <http://www.gnu.org/licenses/>.

GOBJECTS = $(SOURCES:%.scm=%.go)

nobase_mod_DATA = $(SOURCES) $(NOCOMP_SOURCES)
nobase_go_DATA = $(GOBJECTS)

# Make sure source files are installed first, so that the mtime of
# installed compiled files is greater than that of installed source
# files.  See
# <http://lists.gnu.org/archive/html/guile-devel/2010-07/msg00125.html>
# for details.
guile_install_go_files = install-nobase_goDATA
$(guile_install_go_files): install-nobase_modDATA

CLEANFILES = $(GOBJECTS)
EXTRA_DIST = $(SOURCES) $(NOCOMP_SOURCES)
GUILE_WARNINGS = -Wunbound-variable -Warity-mismatch -Wformat
SUFFIXES = .scm .go
.scm.go:
	$(AM_V_GEN)$(top_builddir)/pre-inst-env $(GUILE_TOOLS) compile $(GUILE_WARNINGS) -o "$@" "$<"

moddir=$(prefix)/share/guile/site/$(GUILE_EFFECTIVE_VERSION)
godir=$(libdir)/guile/$(GUILE_EFFECTIVE_VERSION)/site-ccache

SOURCES =					\
  syntax-highlight/utils.scm			\
  syntax-highlight/lexers.scm			\
  syntax-highlight/c.scm			\
  syntax-highlight/css.scm			\
  syntax-highlight/gitignore.scm		\
  syntax-highlight/lisp.scm			\
  syntax-highlight/scheme.scm			\
  syntax-highlight/xml.scm			\
  syntax-highlight.scm

EXTRA_DIST +=					\
  pre-inst-env.in				\
  README					\
  guix.scm

publish: distcheck
	gpg --sign --detach-sign --armor --yes guile-syntax-highlight-$(VERSION).tar.gz && \
        scp guile-syntax-highlight-$(VERSION).tar.gz \
	    guile-syntax-highlight-$(VERSION).tar.gz.asc \
	    publish@dthompson.us:/var/www/files/guile-syntax-highlight/
