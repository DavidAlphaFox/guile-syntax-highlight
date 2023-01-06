dnl -*- Autoconf -*-

AC_INIT(Guile-syntax-highlight, 0.2.0)
AC_CONFIG_SRCDIR(syntax-highlight)
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([color-tests -Wall -Wno-portability foreign])
AM_SILENT_RULES([yes])

AC_CONFIG_FILES([Makefile])
AC_CONFIG_FILES([pre-inst-env], [chmod +x pre-inst-env])

GUILE_PKG([3.0 2.2 2.0])
GUILE_PROGS

AC_OUTPUT
