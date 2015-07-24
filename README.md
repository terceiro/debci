# Debian Continuous Integration

The [Debian continuous integration](..) (debci) is an automated system that
coordinates the execution of automated tests against packages in the
[Debian](http://www.debian.org/) system. `debci` will continuously run
`autopkgtest` test suites from source packages in the Debian archive.

## Documentation for package maintainers

The {file:MAINTAINERS.md FAQ for package maintainers} contains useful
information on how to declare the test suite, how the test is executed,
how to reproduce the test runs locally, etc.

## Deployment

See the {file:INSTALL.md installation guide} for instructions on how to deploy
debci to your own infrastructure.

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

Copyright © 2014-2015 the debci development team.

debci is free software licensed under the GNU General Public License version 3
or later.
