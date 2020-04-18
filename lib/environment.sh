#!/bin/sh

case $- in
  *i*)
    ;;
  *)
    set -eu
    ;;
esac

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

if [ -z "${debci_base_dir:-}" ]; then
  if [ -f lib/environment.sh ]; then
    debci_base_dir="$(pwd)"
  else
    echo "E: no \$debci_base_dir not set!"
    return 1
  fi
fi

# local config file in tree can override global defaults
debci_default_config_dir=$(readlink -f "${debci_base_dir}/config")
debci_config_dir="${debci_config_dir:-${debci_default_config_dir}}"
if [ -r "$debci_config_dir/debci.conf" ]; then
  . "$debci_config_dir/debci.conf"
fi
# load conf.d/ directory
debci_conf_d="${debci_config_dir}/conf.d"
if [ -d "${debci_conf_d}" ]; then
  for config in \
    $(find "${debci_conf_d}" -type f -name '[0-9a-z-_]*.conf' | sort)
  do
    . $config
  done
fi

# default values
# for Debian, NAME is "Debian GNU/Linux", shorten this
debci_distro_name="${debci_distro_name:-$(. /etc/os-release; echo ${NAME% *})}"
debci_suite=${debci_suite:-unstable}
debci_suite_list=${debci_suite_list:-${debci_suite}}
debci_arch=${debci_arch:-$(dpkg --print-architecture)}
debci_arch_list="${debci_arch_list:-${debci_arch}}"
debci_mirror=${debci_mirror:-${MIRROR:-http://deb.debian.org/debian}}
debci_backend=${debci_backend:-lxc}
debci_data_basedir=${debci_data_basedir:-$(readlink -f "${debci_base_dir}/data")}
debci_quiet="${debci_quiet:-false}"
debci_amqp_server=${debci_amqp_server:-"amqp://localhost"}
debci_amqp_ssl=${debci_amqp_ssl:-false}
debci_amqp_cacert=${debci_amqp_cacert:-}
debci_amqp_cert=${debci_amqp_cert:-}
debci_amqp_key=${debci_amqp_key:-}
debci_amqp_results_queue=${debci_amqp_results_queue:-"debci_results"}
debci_swift_url=${debci_swift_url:-}
debci_sendmail_from="${debci_sendmail_from:-$debci_distro_name Continuous Integration <owner@localhost>}"
debci_sendmail_to="${debci_sendmail_to:-%s@localhost}"
debci_url_base="${debci_url_base:-http://localhost:8080}"
debci_artifacts_url_base="${debci_artifacts_url_base:-}"
debci_database_url="${debci_database_url:-sqlite3://$debci_data_basedir/debci.sqlite3?timeout=5000}"
debci_pending_status_per_page="${debci_pending_status_per_page:-50}"
debci_status_visible_days="${debci_status_visible_days:-35}"
debci_failing_packages_per_page="${debci_failing_packages_per_page:-50}"

debci_secrets_dir=${debci_secrets_dir:-$(readlink -f "${debci_base_dir}/secrets")}

shared_short_options='c:s:a:b:d:m:hq'
shared_long_options='config:,suite:,arch:,backend:,data-dir:,amqp:,mirror:,help,quiet'

usage_shared_options="Common options:

  -c DIR, --config DIR      uses DIR as the debci configuration directory
                            (default: ${debci_default_config_dir})
  -a, --arch ARCH           selects the architecture to run tests for
                            (default: host architecture)
  -n, --backend BACKEND     selects the backends to run tests on
                            (default: lxc)
  -s, --suite SUITE         selects suite to run tests for
                            (default: unstable)
  -d DIR, --data-dir DIR    the directory in which debci will store its data,
                            and where it will read from
  --amqp amqp://[user:password@]hostname[:port]
                            AMQP server to connect to (default: ${debci_amqp_server})
  -m URL, --mirror URL      selects which mirror to use for APT-related actions,
                            i.e. creating test backends, pulling sources files, etc.
  -q, --quiet               prevents debci from producing any output on stdout
  --help                    show this usage message
"

program_name=${0##*/}
TEMP=`getopt --name $program_name -o ${shared_short_options}${short_options:-} --long ${shared_long_options},${long_options:-} -- "$@"`

if [ $? != 0 ]; then
  exit 1
fi

eval set -- "$TEMP"

var=''
for arg in "$@"; do
  if [ $var ]; then
    eval "export $var=\"$arg\""
    var=''
  else
    case "$arg" in
      -c|--config)
        var=debci_config_dir
        ;;
      -s|--suite)
        var=debci_suite
        ;;
      -a|--arch)
        var=debci_arch
        ;;
      -b|--backend)
        var=debci_backend
        ;;
      -d|--data-dir)
        var=debci_data_basedir
        ;;
      --amqp)
        var=debci_amqp_server
        ;;
      -m|--mirror)
        var=debci_mirror
        ;;
      -q|--quiet)
        export debci_quiet=true
        ;;
      -h|--help)
        usage "$usage_shared_options"
        exit 0
        ;;
      *)
        var=''
        ;;
    esac
  fi
done

# This is used in lxc by the lxc-debian template, and by autopkgtest-build-*
export MIRROR="${debci_mirror}"

alias prepare_args='while [ "$1" != "--" ]; do shift; done; shift'

debci_autopkgtest_basedir="${debci_data_basedir}/autopkgtest"
debci_autopkgtest_dir="${debci_autopkgtest_basedir}/${debci_suite}/${debci_arch}"
debci_autopkgtest_incoming_basedir="${debci_data_basedir}/autopkgtest-incoming"
debci_autopkgtest_incoming_dir="${debci_autopkgtest_incoming_basedir}/${debci_suite}/${debci_arch}"
debci_packages_dir="${debci_data_basedir}/packages/${debci_suite}/${debci_arch}"
debci_status_dir="${debci_data_basedir}/status/${debci_suite}/${debci_arch}"
debci_html_dir="${debci_data_basedir}/.html"

debci_gnupg_dir="${debci_base_dir}/gnupg"

debci_bin_dir="${debci_base_dir}/bin"

debci_log_dir="${debci_base_dir}/log"

debci_user=$(stat -c %U "${debci_data_basedir}")
debci_uid=$(stat -c %u "${debci_data_basedir}")
debci_group=$(stat -c %G "${debci_data_basedir}")

debci_amqp_queue=${debci_amqp_queue:-"debci-tests-${debci_arch}-${debci_backend}"}

# hide password when displaying AMPQ server
debci_amqp_server_display="$(echo "$debci_amqp_server" | sed -e 's#:[^/]*@#:*********@#')"

debci_amqp_tools_options=
if [ $debci_amqp_ssl = true ]; then
  debci_amqp_tools_options="--ssl"
fi
for var in cacert cert key; do
  value="$(eval "echo \$debci_amqp_${var}")"
  if [ -n "$value" ]; then
    debci_amqp_tools_options="${debci_amqp_tools_options} --${var}=${value}"
  fi
done

debci_lock_dir=${debci_lock_dir:-/var/lock}

# per-suite/architecture lock/timestamp files
debci_testbed_timestamp=${debci_lock_dir}/debci-testbed-${debci_suite}-${debci_arch}-${debci_backend}.stamp
debci_chdist_lock=${debci_lock_dir}/debci-chdist-${debci_suite}-${debci_arch}.lock
debci_batch_lock=${debci_lock_dir}/debci-batch-${debci_suite}-${debci_arch}.lock

# global lock/timestamp files
debci_generate_index_lock=${debci_lock_dir}/debci-generate-index.lock

# data retention policy (numbers of days)
debci_data_retention_days=${debci_data_retention_days:-180}

# extra arguments for autopkgtest
debci_autopkgtest_args="${debci_autopkgtest_args:-}"

# session secret for the web interface
debci_session_secret="${debci_session_secret:-}"

# page to display when authentication fails
debci_auth_fail_page="${debci_auth_fail_page:-}"

for dir in \
  "${debci_base_dir}/backends/${debci_backend}" \
  "${debci_bin_dir}"
do
  if ! (echo "${PATH}" | sed 's/:/\n/g' | grep -q "^${dir}\$"); then
    PATH="${dir}:${PATH}"
  fi
done
