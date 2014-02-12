# Debian continuou integration

THE [Debian continuous integration](.) is an automated system that coordinates
the execution of automated tests against packages in the
[Debian](http://www.debian.org/) system.

## How it works

TODO. For now look at
[source](http://anonscm.debian.org/gitweb/?p=users/terceiro/debci.git;a=summary)

## Setting up a development instance


Install the dependencies (look at debian/control). You probably also want to
install `apt-cacher-ng` to cache package downloads

Trun the following command as root:

    $ ./scripts/setup

Restrict the list of packages you want to run for testing by creating
`config/whitelist` containing one package per line. You will usually want to
test this with small packages that have a small set of dependencies ;-).

Setup a web server pointing to the `public/` directory inside the sources so
you can view the web interface.

To run debci:

    $ ./bin/debci


## Contact

* mailing list: [debian-qa@lists.debian.org](http://lists.debian.org/debian-qa/)
* IRC: `#debian-qa` in the OFTC network (a.k.a `irc.debian.org`). Feel free to
  highlight `terceiro`.

## Copyright and Licensing information

Copyright © 2014 Antonio Terceiro.

debci is free software licensed under the GNU General Public License version 3
or later.
