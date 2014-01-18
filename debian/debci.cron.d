#
# Regular cron jobs for the debci package

PATH=/usr/sbin:/usr/bin:/sbin:/bin

# 13 */6 * * *	root	[ -x /usr/sbin/debci-run ] && /usr/sbin/debci-run
