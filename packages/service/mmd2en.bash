#!/usr/bin/bash
# fall back on bundled mmd binary without clobbering user settings
export MULTIMARKDOWN=${MULTIMARKDOWN:=./bin/multimarkdown}

# Sort out ARGF input because friggin’ Platypus will pass text as arguments, line by line...
for f in "$@"; do
	[[ -f "$f" ]] || { echo "$*" | process; exit $?; }
done
process "$@"

function process { ruby -W0 -E 'UTF-8' ./mmd2en.rb "$@"; }
