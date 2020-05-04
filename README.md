# Debian Continuous Integration

The [Debian continuous integration](..) (debci) is an automated system that
coordinates the execution of automated tests against packages in the
[Debian](https://www.debian.org/) system. `debci` will continuously run
`autopkgtest` test suites from source packages in the Debian archive.

## Documentation for package maintainers

The {file:docs/MAINTAINERS.md FAQ for package maintainers} contains useful
information on how to declare the test suite, how the test is executed,
how to reproduce the test runs locally, etc.

Additionally, we have these extra tutorial-style documentation:

* {file:docs/TUTORIAL.md Functional testing of Debian packages}, a tutorial
  transcribed from a DebConf15 talk on autopkgtest and debci is available that
  covers declaring test suites, issues to consider, and tips and tricks.
* [Patterns for Writing As-Installed Tests for Debian Packages](https://deb.li/pattestdeb)
  is a paper describing patterns (as in "design patterns") for writing tests
  for Debian packages.

## Deployment

See the {file:docs/INSTALL.md installation guide} for instructions on how to
deploy debci to your own infrastructure.

## Reporting Bugs

Please report bugs against the [debci package](https://bugs.debian.org/debci)
in the [Debian BTS](https://bugs.debian.org/).

## Developer information

* Get source: `git clone https://salsa.debian.org/ci-team/debci.git`
* [Browse source](https://salsa.debian.org/ci-team/debci)
* {file:docs/HACKING.md How to setup a development environment}

## Contact

For maintainer queries, general discussion, and also about the development of
debci itself, get in touch:

* mailing list: [debian-ci](https://lists.debian.org/debian-ci)
* IRC: `#debci` on OFTC

## Copyright and Licensing information

Copyright © the debci development team.

debci is free software licensed under the GNU General Public License version 3
or later.
