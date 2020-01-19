#! /bin/sh

set -x
make distclean
aclocal -I build --output=build/aclocal.m4
libtoolize --copy --force
# cp -f ~/cvs/config/config.guess ~/cvs/config/config.sub build/
autoheader
automake --add-missing --copy
autoreconf --localdir=build --gnu

