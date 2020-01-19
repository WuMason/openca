#/bin/sh

## Written by Michael Bell for the OpenCA project
## (c) Copyright 2004 The OpenCA Project

## determine parameters

if test -z "$1"; then 
	echo "You must specify at minimum the link source!"; 
	exit;
fi

## this is not correct for dynamic links
## if test ! -e $1; then echo "The link source must exist!"; exit; fi

source=`basename $1`;
source_dir=`dirname $1`;

if test -z "$2"; then
    target_dir=`pwd`;
    target=$source;
else
    if test -d "$2"; then
        target_dir=$2;
        target=$source;
    else
        target_dir=`dirname $2`;
        target=`basename $2`;
    fi;
fi

if [ -e "${target_dir}/${target}" ] ; then 
	echo "The target file already exists!"; 
	exit;
fi;

## determine common path

temp=$target_dir
target_list=""

while test -n "$temp" && test "$temp" != "." && test "$temp" != "/"; do
    target_list="${temp} ${target_list}";
    temp=`dirname ${temp}`;
done;

temp=$source_dir
source_list=""

while test -n $temp && test $temp != "." && test $temp != "/"; do
    source_list="${temp} ${source_list}";
    temp=`dirname ${temp}`;
done;

common="/"

for path in $source_list; do
    for name in $target_list; do
        if test $name = $path; then common=$path; fi;
    done;
done;

## determine the minimum path from target to common

front=""
path=$target_dir
while test $path != $common && test $path != "." && test $path != "/"; do
    front="../${front}";
    path=`dirname ${path}`;
done;

## determine the minimum path from common to source

back=""
path=$source_dir
while test $path != $common && test $path != "." && test $path != "/"; do
    back="`basename ${path}`/${back}"
    path=`dirname ${path}`;
done;

## build command

cmd="cd ${target_dir} && ln -s $front$back$source $target"

eval $cmd
