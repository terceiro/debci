# Debian continuou integration

THE [Debian continuous integration](.) is an automated system that coordinates
the execution of automated tests against packages in the
[Debian](http://www.debian.org/) system.

## How it works

TODO. For now look at
[source](http://anonscm.debian.org/gitweb/?p=users/terceiro/debci.git;a=summary)

## Setting up a development environment

Install the dependencies and build dependencies (look at debian/control). You
probably also want to install a few other packages:

* `apt-cacher-ng` to cache package downloads.
* `moreutils` if you want to test the supporting for testing packages in parallel.
* `lighttpd` to run the web interface (see below for more information)
  * Note: you might want to not have lighttpd running as a daemon on your system.

After having the dependencies installed, the first step is to set up the test
environment. To do that, you need to run the following command (which needs
root permissions):

    $ sudo ./bin/debci-setup

If you run debci right now, it would run the tests for **every package** in
Debian, and you don't want that for a development environment. To restrict
debci to a list of packages, create a file named `whitelist` inside the
`config` directory, containing one package name per line. Here is an example
with packages whose tests are pretty fast:

```
$ cat config/whitelist
ruby-defaults
rubygems-integration
ruby-ffi
rake
```

You might want to test with other packages, that's fine. Just take into
consideration that the more packages you have, the longer debci will take to
finish a run.

Now you are ready to actually run debci:

    $ ./bin/debci

To visualize the web interface, follow the following steps:

    $ make
    $ ./tools/server.sh

Now browse to [http://localhost:8888/](http://localhost:8888/)

If you think the web interface looks empty, it is because a single debci run
does not provide enough data to work with.  You might want to generate some
fake data so the web interface will look a lot nicer:

    $ ./tools/gen-fake-data.sh


## Contact

* mailing list: [debian-qa@lists.debian.org](http://lists.debian.org/debian-qa/)
* IRC: `#debian-qa` in the OFTC network (a.k.a `irc.debian.org`). Feel free to
  highlight `terceiro`.

## Copyright and Licensing information

Copyright © 2014 Antonio Terceiro.

debci is free software licensed under the GNU General Public License version 3
or later.
