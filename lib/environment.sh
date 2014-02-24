#!/bin/sh

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

if [ -z "$debci_base_dir" ]; then
  if [ -f scripts/process-all-packages -a -f lib/environment.sh ]; then
    debci_base_dir="$(pwd)"
  else
    echo "E: no \$debci_base_dir not set!"
    return 1
  fi
fi

debci_suite='unstable' # FIXME allow passing in via command line
debci_arch=$(dpkg-architecture -qDEB_HOST_ARCH) # FIXME allow passing in via command line

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

debci_backend=schroot # FIXME

for dir in \
  "${debci_base_dir}/backends/${debci_backend}" \
  "${debci_bin_dir}"
do
  if ! (echo "${PATH}" | sed 's/:/\n/g' | grep -q "^${dir}\$"); then
    PATH="${dir}:${PATH}"
  fi
done
