# debci development

## Setting up a development environment

There are two ways to setup the development environment:

* Manual Setup
* Vagrant

## Vagrant

### Prerequisites

* Vagrant: 2.2.4 https://www.vagrantup.com/
* VirtualBox: 6.0 https://www.virtualbox.org/

### Install the virtual machine

Run this at the same path where `VagrantFile` is

```
$ vagrant up
```

### Start debci

SSH into vagrant environment

```
$ vagrant ssh
```

Once inside vagrant, you can start run debci with the following commands

```
vagrant@stretch $ cd /vagrant
vagrant@stretch $ foreman start
```

Note: The other commands are the same as the ones mentioned in manual setup.

## Manual Setup
### Grab the dependencies and required software

Install the dependencies and build dependencies:

```
$ sudo apt-get build-dep .
```

If that fails with a complaint that any package it not recent enough, then you
probably need to enable the [backports repository](https://backports.debian.org/)
and install those packages from there (replace `<stable>` with the current
Debian stable release codename, and `<PACKAGE>` with the package you want to
install):

```
sudo apt-get install -t <stable>-backports <PACKAGE>
```

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

The most common case is that you want to work in aspects of the system that do
not involve the actual test backends, e.g. the user interface, or the database.
For that, you can use helper script to to the setup for you:

    $ ./tools/init-dev.sh

The above script will create:

* a package whitelist in `config/whitelist`; this limits the set of packages
   that will be worked on, reducing the time it takes for processing everything
   on your local tests.
* a configuration file at `config/conf.d/dev.conf` which sets architectures and
  suites. It also sets the debci backend to the `fake` backend, which is very
  fast (because it does not really run tests, it just produces "fake" test runs
  with random results)

Note: the `fake` backend gets package versions from your local system. So, for
example if you are on Debian stable, when "running tests" for package `foo`,
the `fake` backend will report as testing the version of `foo` that is
available on Debian stable. If for some reason you want or need it to report,
say, versions that look like the ones from Debian unstable, all you have to do
is add a `sources.list` entry for Debian unstable, like this:

If you want to work on an actual test backend, then you will want to modify
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

The web UI is generated using Ruby and ERB templates. The {Debci::HTML} class
in `lib/debci/html.rb` is responsible for generating all of the pages for the
web UI by using the templates.

The templates contain HTML and debci Ruby API calls to display information
in the interface.

The templates are contained in the `lib/debci/html/` directory while
the debci Ruby API is contained a directory lower in
`lib/debci/`.

Once you make changes to the templates or other code related to HTML
generation, you can run the following commands to regenerate the HTML for the
interface:

    $ ./bin/debci html update             # update non package-related pages
    $ ./bin/debci html update-package PKG # update all pages for PKG

If you make changes to the documentation (HACKING.md, etc.),
run the following to regenerate it:

    $ make

With the web interface running, you should see your changes with a refresh of
the web page.

**NOTE: Try to keep lines under 80 characters in length unless it would cause
the code to look weird or less readable.**

### Implementing new features for the debci web interface

If you are developing a new feature for the debci web UI, make sure that
if you develop any new debci Ruby API calls that you add tests for them in the
appropriate test file. (e.g. If you add a method to {Debci::Job}, make sure
that the method has tests in `spec/debci/job_spec.rb`)

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

## Contribution guidelines

* If you are new to Free Software/Open Source, read [How to Contribute to Open Source](https://opensource.guide/how-to-contribute/) first.
  * Some of the advice in there is specific to GitHub, but most of it is general enough to be useful.
* Separate commits by logical change
* Write meaningful commit messages. See:
  * [A Note About Git Commit Messages](https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html)
  * [How to Write a Git Commit Message](https://chris.beams.io/posts/git-commit/)
  * [Useful Tips for writing better Git commit messages](https://code.likeagirl.io/useful-tips-for-writing-better-git-commit-messages-808770609503)
* _Read_ your commits before sending them out, i.e. put yourself at the position of others:
  * Was I the one receiving these patches, without knowing what I know after writing them, do they make sense. Are they self-explanatory?
  * Does the coding style (indentation, variable naming, etc) match the existing code?
