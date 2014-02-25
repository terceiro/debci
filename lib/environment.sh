#!/bin/sh

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

if [ -z "$debci_base_dir" ]; then
  if [ -f lib/environment.sh ]; then
    debci_base_dir="$(pwd)"
  else
    echo "E: no \$debci_base_dir not set!"
    return 1
  fi
fi

# default values
debci_suite=${debci_suite:-unstable}
debci_arch=${debci_arch:-$(dpkg-architecture -qDEB_HOST_ARCH)}
debci_backend=${debci_backend:-schroot}

shared_short_options='s:a:b:h'
shared_long_options='suite:,arch:,backend:,help'

usage_shared_options='Common options:

  -a, --arch ARCH           selects the architecture to run tests for
                            (default: host architecture)
  -n, --backend BACKEND     selects the backends to run tests on
                            (default: schroot)
  -s, --suite SUITE         selects suite to run tests for
                            (default: unstable)
  --help                    show this usage message
'

TEMP=`getopt -o ${shared_short_options}${short_options} --long ${shared_long_options},${long_options} -- "$@"`

if [ $? != 0 ]; then
  exit 1
fi

eval set -- "$TEMP"

for arg in "$@"; do
  if [ $var ]; then
    eval "export $var=\"$arg\""
    var=''
  else
    case "$arg" in
      -s|--suite)
        var=debci_suite
        ;;
      -a|--arch)
        var=debci_arch
        ;;
      -b|--backend)
        var=debci_backend
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

debci_data_basedir=$(readlink -f "${debci_base_dir}/data")
debci_data_dir="${debci_data_basedir}/${debci_suite}-${debci_arch}"
debci_packages_dir="${debci_data_dir}/packages"
debci_status_dir="${debci_data_dir}/status"

debci_config_dir="${debci_base_dir}/config"

debci_gnupg_dir="${debci_base_dir}/gnupg"

debci_chroots_dir="${debci_base_dir}/chroots"
debci_chroot_name="debci-${debci_suite}-${debci_arch}"
debci_chroot_path="${debci_chroots_dir}/${debci_suite}-${debci_arch}"

debci_bin_dir="${debci_base_dir}/bin"

debci_user=$(stat -c %U "${debci_data_basedir}")

for dir in \
  "${debci_base_dir}/backends/${debci_backend}" \
  "${debci_bin_dir}"
do
  if ! (echo "${PATH}" | sed 's/:/\n/g' | grep -q "^${dir}\$"); then
    PATH="${dir}:${PATH}"
  fi
done
