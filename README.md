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
used for a test run is show in the corresponfing log file.

For the **schroot** backend:

* The test chroot is a clean chroot, created with debootstrap with no extra arguments.
* dpkg is configured to use the `--force-unsafe-io` option to speed up the installation of packages.
* The chroot uses the [`debci` profile](http://anonscm.debian.org/gitweb/?p=collab-maint/debci.git;a=tree;f=etc/schroot/debci), installed by the `debci` package.

## Reporting Bugs

Please report bugs against the [debci package](https://bugs.debian.org/debci)
in the [Debian BTS](http://bugs.debian.org/).

## Developer information

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
