#
# Regular cron jobs for the dep8 package
#
13 */6 * * *	root	[ -x /usr/sbin/dep8-run ] && /usr/sbin/dep8-run
