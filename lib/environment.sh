#!/bin/sh

if [ -z "$dep8_base_dir" ]; then
  if [ -f scripts/process-all-packages -a -f lib/environment.sh ]; then
    dep8_base_dir="$(pwd)"
  else
    return 1
  fi
fi

dep8_suite='unstable' # FIXME

dep8_data_dir="${dep8_base_dir}/data"
dep8_packages_dir="${dep8_data_dir}/packages"

dep8_config_dir="${dep8_base_dir}/config"

dep8_gnupg_dir="${dep8_base_dir}/gnupg"

dep8_chroots_dir="${dep8_base_dir}/chroots"
dep8_chroot_name="dep8-${dep8_suite}"
dep8_chroot_path="${dep8_chroots_dir}/${dep8_suite}"
