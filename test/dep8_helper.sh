# DEP-8/autopkgtest support: only use local binaries when not running under a
# DEP-8 runner, when you are supposed to test the installed package
if [ -z "${ADTTMP:-}" ]; then
  base=$(readlink -f $(dirname $0)/..)
  export PATH="$base/bin:${PATH}"
  export RUBYLIB="$base/lib"
fi

