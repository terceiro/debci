set -u

# DEP-8/autopkgtest support: only use local binaries when not running under a
# DEP-8 runner, when you are supposed to test the installed package
if [ -z "${ADTTMP:-}" ]; then
  base=$(readlink -f $(dirname $0)/..)
  export PATH="$base/bin:${PATH}"
fi

export debci_quiet='true'
export debci_backend='fake'

setUp() {
  export __tmpdir="$(mktemp -d)"
  mkdir -p $__tmpdir/data
  mkdir -p $__tmpdir/config
  cat > "$__tmpdir/config/whitelist" <<EOF
ruby
ruby-ffi
rubygems-integration
rake
EOF
  export debci_data_basedir="$__tmpdir/data"
  export debci_config_dir="$__tmpdir/config"
}

tearDown() {
  if [ -z "${DEBUG:-}" ]; then
    rm -rf $__tmpdir
  else
    echo "I: test data available in $__tmpdir"
  fi
  unset DEBCI_FAKE_RESULT
  unset DEBCI_FAKE_DEPS
}

result_pass() {
  export DEBCI_FAKE_RESULT="pass"
  "$@"
}

result_fail() {
  export DEBCI_FAKE_RESULT="fail"
  "$@"
}

result_tmpfail() {
  export DEBCI_FAKE_RESULT="tmpfail"
  "$@"
}
