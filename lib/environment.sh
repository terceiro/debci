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
debci_arch=${debci_arch:-$(dpkg --print-architecture)}
# debci-setup-chdist determines the default from debootstrap, don't set one here
debci_mirror=
debci_backend=${debci_backend:-schroot}
debci_data_basedir=${debci_data_basedir:-$(readlink -f "${debci_base_dir}/data")}
debci_quiet="${debci_quiet:-false}"
debci_amqp_server=${debci_amqp_server:-"amqp://localhost"}
debci_amqp_results_queue=${debci_amqp_results_queue:-"debci_results"}
debci_swift_url=${debci_swift_url:-}
debci_sendmail_from="${debci_sendmail_from:-$debci_distro_name Continuous Integration <owner@localhost>}"
debci_sendmail_to="${debci_sendmail_to:-%s@localhost}"
debci_url_base="${debci_url_base:-http://localhost:8888}"
debci_artifacts_url_base="${debci_artifacts_url_base:-}"

shared_short_options='c:s:a:b:d:hq'
shared_long_options='config:,suite:,arch:,backend:,data-dir:,amqp:,help,quiet'

usage_shared_options="Common options:

  -c DIR, --config DIR      uses DIR as the debci configuration directory
                            (default: ${debci_default_config_dir})
  -a, --arch ARCH           selects the architecture to run tests for
                            (default: host architecture)
  -n, --backend BACKEND     selects the backends to run tests on
                            (default: schroot)
  -s, --suite SUITE         selects suite to run tests for
                            (default: unstable)
  -d DIR, --data-dir DIR    the directory in which debci will store its data,
                            and where it will read from
  --amqp amqp://[user:password@]hostname[:port]
                            AMQP server to connect to (default: ${debci_amqp_server})
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

alias prepare_args='while [ "$1" != '--' ]; do shift; done; shift'

debci_autopkgtest_dir="${debci_data_basedir}/autopkgtest/${debci_suite}/${debci_arch}"
debci_autopkgtest_incoming_dir="${debci_data_basedir}/autopkgtest-incoming/${debci_suite}/${debci_arch}"
debci_packages_dir="${debci_data_basedir}/packages/${debci_suite}/${debci_arch}"
debci_status_dir="${debci_data_basedir}/status/${debci_suite}/${debci_arch}"
debci_html_dir="${debci_data_basedir}/.html"

debci_gnupg_dir="${debci_base_dir}/gnupg"

debci_chroots_dir="${debci_base_dir}/chroots"
debci_chroot_name="debci-${debci_suite}-${debci_arch}"
debci_chroot_path="${debci_chroots_dir}/${debci_chroot_name}"

debci_bin_dir="${debci_base_dir}/bin"

debci_log_dir="${debci_base_dir}/log"

debci_user=$(stat -c %U "${debci_data_basedir}")
debci_uid=$(stat -c %u "${debci_data_basedir}")
debci_group=$(stat -c %G "${debci_data_basedir}")

debci_amqp_queue=${debci_amqp_queue:-"debci-${debci_suite}-${debci_arch}-${debci_backend}"}

debci_lock_dir=${debci_lock_dir:-/var/lock}

# lock/timestamp files
debci_testbed_lock=${debci_lock_dir}/debci-testbed-${debci_suite}-${debci_arch}-${debci_backend}.lock
debci_testbed_timestamp=${debci_lock_dir}/debci-testbed-${debci_suite}-${debci_arch}-${debci_backend}.stamp
debci_chdist_lock=${debci_lock_dir}/debci-chdist-${debci_suite}-${debci_arch}.lock
debci_generate_index_lock=${debci_lock_dir}/debci-generate-index-${debci_suite}-${debci_arch}.lock
debci_batch_lock=${debci_lock_dir}/debci-batch-${debci_suite}-${debci_arch}.lock


for dir in \
  "${debci_base_dir}/backends/${debci_backend}" \
  "${debci_bin_dir}"
do
  if ! (echo "${PATH}" | sed 's/:/\n/g' | grep -q "^${dir}\$"); then
    PATH="${dir}:${PATH}"
  fi
done
