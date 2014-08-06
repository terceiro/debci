# Debian Contious Integration

The [Debian continuous integration](..) (debci) is an automated system that
coordinates the execution of automated tests against packages in the
[Debian](http://www.debian.org/) system. `debci` will continuously run
`autopkgtest` test suites from source packages in the Debian archive.

## FAQ for package maintainers

### How do I get my package to have its test suite executed?

Testuites must be included in source packages as defined in
the [DEP-8 specification](http://dep.debian.net/deps/dep8/). In short.

* The fact that the package has a test suite must be declared by adding a
  `Testsuite: autopkgtest` entry to the source stanza in `debian/control`.
* tests are declared in `debian/tests/control`.

Please refer to the DEP-8 spec for details on how to declare your tests.

### How exactly is the test suite executed?

Test suites are executed by
[autopkgtest](http://packages.debian.org/autopkgtest). The version of
autopkgtest used to execute the tests is shown in the log file for each test
run.

### How often are test suites executed?

The test suite for a source package will be executed:

* when any package in the dependency chain of its binary packages changes;
* when 1 month is passed since the test suite was run;

### What exactly is the environment where the tests are run?

`debci` is designed to support several text execution backends. The backend
used for a test run is displayed in the corresponding log file.

For the **schroot** backend:

* The test chroot is a clean chroot, created with debootstrap with no extra arguments.
* dpkg is configured to use the `--force-unsafe-io` option to speed up the installation of packages.
* The chroot uses the [`debci` profile](http://anonscm.debian.org/gitweb/?p=collab-maint/debci.git;a=tree;f=etc/schroot/debci), installed by the `debci` package.

### How can I reproduce the test run locally?

**NOTE:** if you intend to run tests frequently, you should consider installing
`apt-cacher-ng` before anything else. `debci` will notice the running proxy and
will setup the testbed to use it, so you won't have to wait for the download of
each package more than once.

Install a configure `debci`

```
$ sudo apt install debci
$ sudo debci setup
```

Now edit  `/etc/schroot/chroot.d/debci-SUITE-ARCH` (by default `SUITE` is
`unstable` and `ARCH` is your native architecture), and add your username to
the `users`, `root-users` and `source-root-users` configuration keys:

```
[...]
users=debci,$YOUR_USERNAME
[...]
root-users=debci,$YOUR_USERNAME
source-root=users=debci,$YOUR_USERNAME
[...]
```

To speed up test suite execution, you can also add the following line at the
end:

```
union-overlay-directory=/dev/shm
```

This will mount the chroot overlay on `tmpfs` which will make installing test
dependencies a lot faster. If your hard disk is already a SSD, you probably
don't need that. If you don't have a good amount of RAM, you may have problems
using this.


The following examples assume:

* the `schroot` debci backend
* suite = `unstable` (the default)
* architecture = `amd64`

To run the test suite **from a source package in the archive**, you pass the
_package name_ to adt-run:

```
$ adt-run --user debci --output-dir /tmp/output-dir SOURCEPACKAGE --- schroot debci-unstable-amd64
```

To run the test suite against **a locally-built source package**, using the
test suite from that source package and the binary packages you just built, you
can pass the `.changes` file to adt-run:

```
$ adt-run --user debci --output-dir /tmp/output-dir \
  /path/to/PACKAGE_x.y-z_amd64.changes \
  schroot debci-unstable-amd64
```

For more details, see the documentation for the `autopkgtest` package.


## Reporting Bugs

Please report bugs against the [debci package](https://bugs.debian.org/debci)
in the [Debian BTS](http://bugs.debian.org/).

## Developer information

* Get source: `git clone https://alioth.debian.org/anonscm/git/collab-maint/debci.git`
* [Browse source](http://anonscm.debian.org/gitweb/?p=collab-maint/debci.git)
* {file:HACKING.md How to setup a development environment}
* {file:RUBYAPI.md The Ruby API to the debci data store}

## Contact

For maintainer queries and general discussion:

* mailing list: [debian-qa@lists.debian.org](http://lists.debian.org/debian-qa/)
* IRC: `#debian-qa` on OFTC. Feel free to highlight `terceiro`

For the development of debci itself

* mailing list: [autopkgtest-devel](http://lists.alioth.debian.org/cgi-bin/mailman/listinfo/autopkgtest-devel)
* IRC: `#debci` on OFTC

## Copyright and Licensing information

Copyright © 2014 the debci development team.

debci is free software licensed under the GNU General Public License version 3
or later.
