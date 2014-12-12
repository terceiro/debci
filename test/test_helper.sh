set -u

. $(dirname $0)/dep8_helper.sh

TEST_RABBIT_PORT=5677

export debci_quiet='true'
export debci_backend='fake'
export debci_amqp_server="amqp://localhost:$TEST_RABBIT_PORT"

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

autopkgtest_dir_for_package() {
  local pkg="$1"
  pkg_dir=$(echo "$pkg" | sed -e 's/\(\(lib\)\?.\).*/\1\/&/')
  echo "${debci_data_basedir}/autopkgtest/unstable/amd64/${pkg_dir}"
}

tearDown() {
  stop_worker
  if [ -z "${DEBUG:-}" ]; then
    rm -rf $__tmpdir
  else
    echo "I: test data available in $__tmpdir"
  fi
  unset DEBCI_FAKE_RESULT
  unset DEBCI_FAKE_DEPS
}

oneTimeTearDown() {
  stop_rabbitmq_server
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

TEST_RABBIT_SERVER_DIR=''
TEST_RABBIT_SERVER_PID=''

start_rabbitmq_server() {
  if [ -n "$TEST_RABBIT_SERVER_DIR" ]; then
    return
  fi
  TEST_RABBIT_SERVER_DIR=$(mktemp -d --tmpdir debci.rabbitmq.XXXXXX)
  mkdir -p $TEST_RABBIT_SERVER_DIR/log
  export RABBITMQ_NODENAME=debci-test
  export RABBITMQ_NODE_PORT=$TEST_RABBIT_PORT
  env RABBITMQ_MNESIA_BASE=$TEST_RABBIT_SERVER_DIR/mnesia \
    RABBITMQ_LOG_BASE=$TEST_RABBIT_SERVER_DIR/log \
    RABBITMQ_NODE_IP_ADDRESS=127.0.0.1 \
    HOME=$TEST_RABBIT_SERVER_DIR \
    /usr/lib/rabbitmq/bin/rabbitmq-server > $TEST_RABBIT_SERVER_DIR/log/output.txt 2>&1 &
  TEST_RABBIT_SERVER_PID=$!

  HOME=$TEST_RABBIT_SERVER_DIR /usr/lib/rabbitmq/bin/rabbitmqctl wait \
      -q $TEST_RABBIT_SERVER_DIR/mnesia/debci-test.pid

  if [ -n "${DEBUG:-}" ]; then
    echo "started local rabbit server"
  fi
}

stop_rabbitmq_server() {
  if [ -z "$TEST_RABBIT_SERVER_DIR" ]; then
    return
  fi
  if [ -n "${DEBUG:-}" ]; then
    echo "stopping local rabbit server"
  fi
  kill -9 $TEST_RABBIT_SERVER_PID
  wait $TEST_RABBIT_SERVER_PID
  if [ -z "${DEBUG:-}" ]; then
    rm -rf "$TEST_RABBIT_SERVER_DIR"
  else
    echo "I: test rabbitmq-server dir available in $TEST_RABBIT_SERVER_DIR"
  fi
  TEST_RABBIT_SERVER_DIR=''
  TEST_RABBIT_SERVER_PID=''
}

TEST_WORKER_PID=''

start_worker() {
  start_rabbitmq_server
  stop_worker  # in case a test does multiple runs under different modes
  export debci_batch_poll_interval="0.1"
  debci worker &
  TEST_WORKER_PID=$!
  if [ -n "${DEBUG:-}" ]; then
    echo "started worker $TEST_WORKER_PID"
  fi
}

stop_worker() {
  if [ -n "$TEST_WORKER_PID" ]; then
    if [ -n "${DEBUG:-}" ]; then
      echo "cleaning up worker $TEST_WORKER_PID"
    fi
    kill $TEST_WORKER_PID 2>/dev/null && wait $TEST_WORKER_PID || true
    TEST_WORKER_PID=
  fi
}
