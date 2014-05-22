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

if [ -r /etc/default/debci ]; then
  . /etc/default/debci
fi

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
if [ -r "$debci_config_dir/debci" ]; then
  . "$debci_config_dir/debci"
fi

# default values
debci_suite=${debci_suite:-unstable}
debci_arch=${debci_arch:-$(dpkg --print-architecture)}
debci_backend=${debci_backend:-schroot}
debci_data_basedir=${debci_data_basedir:-$(readlink -f "${debci_base_dir}/data")}
debci_quiet="${debci_quiet:-false}"

shared_short_options='c:s:a:b:d:hq'
shared_long_options='config:,suite:,arch:,backend:,data-dir:,help,quiet'

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
  -q, --quiet               prevents debci from producing any output on stdout
  --help                    show this usage message
"

TEMP=`getopt -o ${shared_short_options}${short_options:-} --long ${shared_long_options},${long_options:-} -- "$@"`

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
debci_packages_dir="${debci_data_basedir}/packages/${debci_suite}/${debci_arch}"
debci_status_dir="${debci_data_basedir}/status/${debci_suite}/${debci_arch}"

debci_gnupg_dir="${debci_base_dir}/gnupg"

debci_chroots_dir="${debci_base_dir}/chroots"
debci_chroot_name="debci-${debci_suite}-${debci_arch}"
debci_chroot_path="${debci_chroots_dir}/${debci_chroot_name}"

debci_bin_dir="${debci_base_dir}/bin"

debci_user=$(stat -c %U "${debci_data_basedir}")
debci_uid=$(stat -c %u "${debci_data_basedir}")

for dir in \
  "${debci_base_dir}/backends/${debci_backend}" \
  "${debci_bin_dir}"
do
  if ! (echo "${PATH}" | sed 's/:/\n/g' | grep -q "^${dir}\$"); then
    PATH="${dir}:${PATH}"
  fi
done
