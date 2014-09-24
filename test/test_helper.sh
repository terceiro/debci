set -u

. $(dirname $0)/dep8_helper.sh

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
  export debci_arch=$(dpkg --print-architecture)
}

status_dir_for_package() {
  local pkg="$1"
  pkg_dir=$(echo "$pkg" | sed -e 's/\(\(lib\)\?.\).*/\1\/&/')
  echo "${debci_data_basedir}/packages/unstable/${debci_arch}/${pkg_dir}"
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
