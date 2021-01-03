set -u

. $(dirname $0)/dep8_helper.sh

TEST_RABBIT_PORT=5677

export DEBCI_RUNNING_TESTS=yes
if [ -z "${DEBUG:-}" ]; then
  export debci_quiet='true'
else
  export debci_quiet='false'
fi
export debci_backend='fake'
export debci_amqp_server="amqp://localhost:$TEST_RABBIT_PORT"
export debci_amqp_queue="debci-$(dpkg --print-architecture)-test"

if [ $# -gt 0 ]; then
  export TESTCASES="$@"
  suite() {
    for t in $TESTCASES; do
      suite_addTest "$t"
    done
  }
  set --
fi

setUp() {
  export __tmpdir="$(mktemp -d --tmpdir debci.data.XXXXXX)"
  mkdir -p $__tmpdir/data
  mkdir -p $__tmpdir/config
  mkdir -p $__tmpdir/lock
  cat > "$__tmpdir/config/whitelist" <<EOF
ruby
ruby-ffi
rubygems-integration
rake
EOF
  export debci_data_basedir="$__tmpdir/data"
  export debci_config_dir="$__tmpdir/config"
  export debci_lock_dir="$__tmpdir/lock"
  export debci_arch=$(dpkg --print-architecture)
  export debci_secrets_dir="$__tmpdir/secrets"
  debci migrate --quiet
}

status_dir_for_package() {
  local pkg="$1"
  pkg_dir=$(echo "$pkg" | sed -e 's/\(\(lib\)\?.\).*/\1\/&/')
  echo "${debci_data_basedir}/packages/unstable/${debci_arch}/${pkg_dir}"
}

autopkgtest_dir_for_package() {
  local pkg="$1"
  pkg_dir=$(echo "$pkg" | sed -e 's/\(\(lib\)\?.\).*/\1\/&/')
  echo "${debci_data_basedir}/autopkgtest/unstable/${debci_arch}/${pkg_dir}"
}

tearDown() {
  stop_worker
  stop_collector
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
    RABBITMQ_SCHEMA_DIR=$TEST_RABBIT_SERVER_DIR/schema \
    RABBITMQ_GENERATED_CONFIG_DIR=$TEST_RABBIT_SERVER_DIR/config \
    RABBITMQ_NODE_IP_ADDRESS=127.0.0.1 \
    RABBITMQ_CONFIG_FILE=/dev/null \
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

  env RABBITMQ_MNESIA_BASE=$TEST_RABBIT_SERVER_DIR/mnesia \
    RABBITMQ_LOG_BASE=$TEST_RABBIT_SERVER_DIR/log \
    RABBITMQ_NODE_IP_ADDRESS=127.0.0.1 \
    HOME=$TEST_RABBIT_SERVER_DIR \
    /usr/lib/rabbitmq/bin/rabbitmqctl stop > $TEST_RABBIT_SERVER_DIR/log/stop_output.txt 2>&1 &

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
  export WORKER_START_TIMESTAMP=$(date +%s)
  start_rabbitmq_server
  stop_worker  # in case a test does multiple runs under different modes
  start_collector
  export debci_batch_poll_interval="0.1"
  PATH="$testbin:$PATH" debci worker &
  TEST_WORKER_PID=$!
  sleep 0.1
  if [ -n "${DEBUG:-}" ]; then
    echo "started worker $TEST_WORKER_PID"
  fi
}

stop_worker() {
  stop_collector
  if [ -n "$TEST_WORKER_PID" ]; then
    if [ -n "${DEBUG:-}" ]; then
      echo "cleaning up worker $TEST_WORKER_PID"
    fi
    kill $TEST_WORKER_PID 2>/dev/null && wait $TEST_WORKER_PID || true
    TEST_WORKER_PID=
  fi
}

COLLECTOR_PID=''

start_collector() {
  if [ -z "$COLLECTOR_PID" ]; then # won't start multiple collectors
    debci collector &
    COLLECTOR_PID=$!
  fi
}

stop_collector() {
  if [ -n "$COLLECTOR_PID" ]; then
    kill $COLLECTOR_PID
    amqp-delete-queue --url $debci_amqp_server -q debci_results > /dev/null
    COLLECTOR_PID=''
  fi
}

clean_queue() {
  amqp-delete-queue --url $debci_amqp_server -q $debci_amqp_queue
}

testbin="$(dirname $0)/bin"
wait_for_results() {
  "$testbin"/wait_for_results "$@"
}
