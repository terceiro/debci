# debci development

## Setting up a development environment

### Grab the dependencies and required software

Install the dependencies and build dependencies (look at debian/control).


One of the dependencies that you should have installed above is
`rabbitmq-server`. You might not want to have it running at all times. To
disable `rabbitmq-server`, you can run:

```
$ sudo systemctl disable rabbitmq-server
```

If you disabled rabbitmq-server, you will have to remember to start it before
hacking on debci:

```
$ service rabbitmq-server start
```

### Set up the test environment

After having the dependencies installed, you now have to do some setup. The
exact steps depend on your goal with debci.

The most common case isthat you want to work in aspects of the system that do
not involve the actual test backends, e.g. the user interface, or the database.
For that, you can use helper script to to the setup for you:

    $ ./tools/init-dev.sh

The above script will create:

* a package whitelist in `config/whitelist`; this limits the set of packages
   that will be worked on, reducing the time it takes for processing everything
   on your local tests.
* a configuration file at `config/conf.d/dev.conf` which sets architectures and
  suites. It also sets the debci backend to the `fake` backend, which is very
  fast (because it does not really runs tests, just produces "fake" test runs
  with random results)

Note: the `fake` backend gets packages versions from your local system. So, for
example if you are on Debian stable, when "running tests" for package `foo`,
the `fake` backend will report as testing the version of `foo` that is
available on Debian stable. If for some reason you want or need it to report,
say, versions that look like the ones from Debian unstable, all you have to do
is add a `sources.list` entry for Debian unstable, like this:

If you wan to work on an actual test backend, then you will want o modify
`config/conf.d/dev.conf` to set the backend to the one you want to work on.

### Get debci up and running

Now you need to compile a few files that will be part of the user interface:

```
$ make
```

Now initialize the database:

```
$ ./bin/debci migrate
```

Create a local distribution with chdist:

```
$ ./bin/debci setup-chdist
```

debci is composed of a few daemons; you can run all of them in one shot by
running:

```
$ foreman start
```

This will start:

- one debci worker daemon, which runs tests.
- one debci collector daemon, which receives test results, and generates data files and HTML for the web interface.
- one web server daemon.
- one indexer daemon, which generates the HTML UI from the data directory

Now leave those daemons running, and open a new terminal to continue working.

To visualize the web interface, browse to
[http://localhost:8080/](http://localhost:8080/)

You will notice that the web interface looks a little empty. To generate some
test data, run

    $ ./tools/gen-fake-data.sh

The command above will submit one test job for each package on each suite and
each architecture. If you changed the backend from `fake` to something else,
you might not want to do this.

If you go back to the terminal that is running the debci daemons, you will see
a  few messages there related to test jobs you just submitted.

To schedule a single test run, run:

```
$ ./bin/debci enqueue $PACKAGE
```

## debci web UI development

### Starting out

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

### Implementing new features for the debci web interface

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

# Development environment with vagrant

Bring up the vagrant virtual machine:

    $ vagrant up

After that, the system should be properly setup. To run the tests, enter the VM
(`vagrant ssh`), and from there:

    $ cd /vagrant
    $ make test


To run the system:

    $ foreman start

The web UI will be available at http://localhost:8080/ from your host machine.
