# debci - setting up a development environment

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

Once the setup is complete, run the following (where ${debci-root} is the path
to the debci root directory):

    $ sudo ln -s ${debci-root}/etc/schroot/debci /etc/schroot/debci

If you run debci right now, it would run the tests for **every package** in
Debian that has tests, and you don't want that for a development environment.
To restrict debci to a list of packages, create a file named `whitelist` inside
the `config` directory, containing one package name per line. Here is an
example with packages whose tests are pretty fast:

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

If you don't need to test the process of actually running tests (e.g. you are
only working on the user interface), you can also make debci use the "fake"
backend. This backend does not actually do anything, and will mark test runs as
passed or failed randomly. To do that, create `config/debci.conf` with the
following contents:

```
debci_backend=fake
```

debci is composed of a few daemons. You can run all of them in one shot by
installing the `ruby-foreman` package and running:

```
$ make
$ foreman start
```

This will start:

- one debci worker daemon, which runs tests.
- one debci collector daemon, which receives test results, and generates data files and HTML for the web interface.
- one web server daemon.

To visualize the web interface, browse to
[http://localhost:8888/](http://localhost:8888/)

To schedule a batch of test runs, run

```
$ ./bin/debci batch
```

To schedule a single test run, run:

```
$ ./bin/debci enqueue $PACKAGE
```

If you think the web interface looks empty, it is because a single debci run
does not provide enough data to work with.  You might want to generate some
fake data so the web interface will look a lot nicer:

    $ ./tools/gen-fake-data.sh

# debci web UI development

## Starting out
If you are interested in working on the web UI, first make sure that you have
a development environment setup and some test data.

The web UI is generated using Ruby and ERB templates. A {Debci::HTML} object
in `bin/debci-generate-html` generates all of the pages for the web UI by
using the templates.

The templates contain HTML and debci Ruby API calls to display information
in the interface.

The templates are contained in the `lib/debci/html/` directory while
the debci Ruby API is contained a directory lower in
`lib/debci/`.

Once you make changes to the templates or other code for the web UI,
run the following to regenerate the HTML for the interface:

    $ ./bin/debci generate-html

If you make changes to the documentation (HACKING.md, RUBYAPI.md, etc.),
run the following to regenerate it:

    $ make

With the web interface running, you should see your changes with a refresh of
the web page.

**NOTE: Try to keep lines under 80 characters in length unless it would cause
the code to look weird or less readable.**

## Implementing new features for the debci web interface

If you are developing a new feature for the debci web UI, make sure that
if you develop any new debci Ruby API calls that you add tests for them in the
appropriate test file. (e.g. If you add a method to {Debci::Repository}, make
sure that the method has tests in `spec/debci/repository_spec.rb`)

### Running tests on your code

After adding tests for the new method in the appropriate test file, run the
following:

    $ make spec

This will run all tests using rspec. You should see output similar to the
following:

    rspec --color
    ................................................................

    Finished in 0.05459 seconds
    64 examples, 0 failures

If your code passed the appropriate tests, you will see that there
are no failures reported by rspec.
