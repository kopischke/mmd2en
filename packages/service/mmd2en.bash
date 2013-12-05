# Sort out ARGF input because friggin’ Platypus will pass text as arguments, line by line...
for f in "$@"; do
	[[ -f "$f" ]] || { echo "$@" | ruby -KuW0 ./mmd2en.rb; exit $?; }
done
ruby -KuW0 ./mmd2en.rb "$@"
