#!/bin/sh

if [ -z "$debci_base_dir" ]; then
  if [ -f scripts/process-all-packages -a -f lib/environment.sh ]; then
    debci_base_dir="$(pwd)"
  else
    echo "E: no \$debci_base_dir not set!"
    return 1
  fi
fi

debci_suite='unstable' # FIXME

debci_data_dir=$(readlink -f "${debci_base_dir}/data")
debci_packages_dir="${debci_data_dir}/packages"
debci_status_dir="${debci_data_dir}/status"

debci_config_dir="${debci_base_dir}/config"

debci_gnupg_dir="${debci_base_dir}/gnupg"

debci_chroots_dir="${debci_base_dir}/chroots"
debci_chroot_name="debci-${debci_suite}"
debci_chroot_path="${debci_chroots_dir}/${debci_suite}"

debci_user=$(stat -c %U "${debci_data_dir}")
