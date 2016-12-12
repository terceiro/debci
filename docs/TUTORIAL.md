# Tutorial: Functional testing of Debian packages

This is a transcription of a Debconf15 talk, which you might want to
[watch](http://meetings-archive.debian.net/pub/debian-meetings/2015/debconf15/Tutorial_functional_testing_of_Debian_packages.webm)
(WebM format, 469MB).

Do you maintain a Debian package? This tutorial covers implementing autopkgtests
for your Debian packages.

Before covering how to get your package(s) running under autopkgtest, let's
cover a few preliminary topics. If you already have knowledge about the
topics below, feel free to skip to the `Adding tests` section of the tutorial.

## What is autopkgtest?

autopkgtest establishes a standard interface to define and run "as-installed"
tests of packages, i.e. the testing of packages in context as close as possible
to a Debian system where the packages subject to testing are properly installed.

## The DEP-8 specification

Information on the DEP-8 specification is available from http://dep.debian.net/deps/dep8.

There are two basic elements of this specification:

* The `Source` stanza of your Debian control file declaring that the package has
a testsuite.
* An extra control file in `debian/tests/`

### Declaring that a package has a testsuite

This can be done by adding a `Testsuite` field with `autopkgtest` as the value.

**debian/control**

```
Source: foo
[...]
Testsuite: autopkgtest
```

You can also use other values. One such value is autopkgtest-pkg-`language`.
This helps to identify how to run the tests in the package.

### Adding the extra control file

Once you have the debian/control file completed, you need to create an extra
control file in debian/tests (i.e. debian/tests/control).

In this file, you list your tests for the package.

**debian/tests/control**

```
Tests: foo bar baz
```

In this example, there are three tests declared and `foo`, `bar`, and `baz` must
be executables in debian/tests/.

There can also be extra fields in the debian/tests/control file.
You can use Depends:

```
Depends: @, test-tool
```

The `@` symbol means all the binaries of this source package. So, when the testbed
is prepared, all of the binaries will be installed in addition to the ones you declare.

In this case, all the binaries will be installed and some test tool will be installed
to run tests.

# Adding tests
## Tests with different characteristics

You can also have multiple tests with different characteristics.
To do this, multiple stanzas must be in the control file.

```
Tests: test-my-package
Depends: @, test-tool

Tests: smoke-test
```
In this case, there is one test program that needs a given test tool and
some smoke test that does not need anything besides the binary.

If nothing is declared, the Depends values are assumed to be binaries.
`@` will be the default value.

If you just need your binaries, you do not need to declare anything.

### Build dependencies

Build dependencies are also needed to run tests. Let's assume you want
to run an upstream test suite which uses x unit framework or other frameworks.
You can use that framework and your build dependencies.

```
Test: upstream-tests
Depends: @, @builddeps@
```

### Additional Requirements

Restrictions can also be specified on the tests. It is an additional requirement.
Let's look at an example.

```
Tests: break-the-world
Restrictions: breaks-testbed
```

The above states that the tests break the testbed. It puts the testbed into a state
that is not going to work when you run a second test on it.

In this case, there is only one test. If you have more than one test though, and
`breaks-testbed` is specified you will instantiate a new testbed for each test.
Otherwise, you just use the same one.

*Note: If you run these tests outside a VM or a container, the virtualization driver
will skip these tests. On your main system, especially as root, these tests are going
to be skipped so that your main system is not broken.*

### Tests that need root access

It can also be specified that the tests need root access. You may need to think
twice before doing this.

```
Tests: play-with-danger
Restrictions: needs-root
```

### Allowing output to standard error (stderr)

If the tests output anything on the standard error stream, then it's considered
a failure. To overcome this, `allow-stderr` needs to be declared in the Restrictions
header.

```
Tests: complain-but-succeed
Restrictions: allow-stderr
```

### Isolating tests with a container

The level of isolation you want from your host system can also be specified.
If `isolation-container` is declared in the Restrictions header, then the only
things as isolated as a container or more will be able to run the tests.

So, if you want to mess with system services by stopping, starting, etc services,
you do not want that to run in your chroot because it will cause problems.

```
Tests: mess-with-services
Restrictions: isolation-container
```

### Isolating tests with a virtual machine

Tests can also be isolated to running in a virtual machine. This is specified by
declaring `isolation-machine`. This provides even more isolation than a container.
This can be useful for loading kernel modules and test things related to the
kernel.

```
Tests: mess-with-kernel
Restrictions: isolation-machine
```

### Installing Recommends

You can also state that a package needs the Recommends to be installed using
the `needs-recommends` value.

```
Tests: test-extra-features
Restrictions: needs-recommends
```

## Tools

### sadt

sadt, which is part of devscripts, runs tests from the root of a source package
in the current directory on the current system.

It is somewhat limited since it will possibly skip some tests but is useful as a
first step.

### adt-run

adt-run, from autopkgtest, can run tests from the current directory, the USC, a changefile,
or pass additional binary DEBs.

```
$ adt-run [adt-run options] --- [virtualization args]
```

Three dashes are passed to adt-run after the input options followed by virtualization options
which specifies which virtual environment to use to run the tests.

Let's look at a basic example:

```
$ adt-run ./ --- null
```

The command above runs the tests from the source package at the current directory, on the
current system. Note the `null` argument for the virtualization.

Let's look at an example that uses virtualization:

```
$ adt-run -u debci /path/to/foo_1.2.3.-1_amd64.changes --- schroot debci-unstable-amd64
```

The command above runs tests from the source referenced by the `changes` file, using
its binaries, under a user called `debci`. The tests are being run in a `schroot` session
based on the `debci-unstable-amd64` chroot.

You can also use other virtualization tools, such as `lxc`, `qemu`, and `ssh`.

Note: `ssh` assumes that you have a driver to instantiate VMs on the cloud or another remote
location.

```
$ adt-run -u debci /path/to/foo_1.2.3-1_amd64.changes --- lxc adt-sid-amd64
```


# Functional tests by example (plus tips and tricks)

Let's look at a couple of package examples that have autopkgtest support.

## Package: pinpoint

In pinpoint's `debian/tests/control` file, the following is declared:

```
Tests: smoke-tests
Depends: @, file, shunit2
```

As you can see, pinpoint has a very simple test definition. It has a simple test
script called `smoke-tests` and it uses its own binaries (noted by the `@`), file,
and shunit2.

### `Tip 1: Use shunit2`

The smoke-tests file contains the following:

```
#!/bin/sh

exec 2>&1

set -e

test_pdf_output() {
  pdf=$ADTTMP/introduction.pdf
  pinpoint -o $pdf introduction.pin
  assertEquals "application/pdf" "$(file --mime-type --brief $pdf)"
}

test_pdf_output_with_empty_background() {
  pdf=$ADTTMP/global-background.pdf
  pin=$ADTTMP/global-background.pin
  cat > $pin <<EOF
[]
--
test
EOF
  pinpoint -o $pdf $pin
  assertEquals "application/pdf" "$(file --mime-type --brief $pdf)"
}

. shunit2
```
Then, we can run it with sadt or adt-run.

Note: `sadt` hides output and `adt-run ./ --- null` gives full output.


# Miscellaneous

In addition to https://ci.debian.net, CI data is also available in the
UDD/DMD, [DDPO](https://qa.debian.org/developer.php), and
[package tracker](https://packages.qa.debian.org/common/index.html).
