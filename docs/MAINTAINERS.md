# FAQ for package maintainers

## How can I reproduce the test run locally?

**NOTE:** if you intend to run tests frequently, you should consider installing
`apt-cacher-ng` before anything else. `debci` will notice the running proxy and
will setup the testbed to use it, so you won't have to wait for the download of
each package more than once.

### Using no virtualization backend

This is the fastest way to run tests, but does not reproduce the continuous
integration environment faithfully and your local environment may make the
results unreliable. It's useful nevertheless when initially writing the tests,
or for quick runs against your main host system.

To run the test suite from **the root of a source package** against the
currently installed packages, run:

```
$ adt-run --output-dir /tmp/output-dir ./ --- null
```

For more details, see the documentation for the `autopkgtest` package.

### Using the lxc backend (default as of debci >= 1.0)

First step is to configure networking for the lxc containers.  The easiest way
to to that is by using the libvirt networking support. First, install the
necessary packages and activate the default libvirt network:

```
# apt install lxc libvirt-clients libvirt-daemon-system
# virsh net-start default
# virsh net-autostart default
```

**Note:** the default libvirt network will use the `192.168.122.0/24` network.
If that conflicts with your local network, you will need to configure it to use
a different IP range.

Now configure lxc to use the default libvirt network, by putting the following
content in `/etc/lxc/default.conf`:

```
lxc.network.type = veth
lxc.network.link = virbr0
lxc.network.flags = up
```

You will also need permissions to run the `lxc-*` commands as root, preserving
your environment. An easy way to do that is to drop the following content into
`/etc/sudoers.d/lxc`, replacing `YOUR_USERNAME` by your actual username.

```
YOUR_USERNAME       ALL = NOPASSWD:SETENV: /usr/bin/lxc-*
```

Now install and configure `debci`:

```
$ sudo apt install debci autopkgtest
$ sudo debci setup
```

This might take a few minutes since it will create a fresh container from
stratch.

Now to actually run tests, we'll use the adt-run tool from `autopkgtest`
directly. The following examples assume your architecture is amd64, replace it
by your actual architecture if that is not the case.

To run the test suite **from a source package in the archive**, just pass the
_source package name_ to adt-run:

```
$ adt-run --user debci --output-dir /tmp/output-dir SOURCEPACKAGE --- lxc --sudo adt-sid-amd64
```

To run the test suite against **a locally-built source package**, using the
test suite from that source package and the binary packages you just built, you
can pass the `.changes` file to adt-run:

```
$ adt-run --user debci --output-dir /tmp/output-dir \
  /path/to/PACKAGE_x.y-z_amd64.changes \
  --- lxc --sudo adt-sid-amd64
```

For more details, see the documentation for the `autopkgtest` package.

### Using the schroot backend

Install a configure `debci` and `schroot`:

```
$ sudo apt install debci autopkgtest schroot
$ sudo debci setup --backend schroot
```

Edit  `/etc/schroot/chroot.d/debci-SUITE-ARCH` (by default `SUITE` is
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
  --- schroot debci-unstable-amd64
```

For more details, see the documentation for the `autopkgtest` package.

## How do I get my package to have its test suite executed?

Test suites must be included in source packages as defined in
the [DEP-8 specification](http://dep.debian.net/deps/dep8/). In short.

* The fact that the package has a test suite must be declared by adding a
  `Testsuite: autopkgtest` entry to the source stanza in `debian/control`.
  * if the package is built with dpkg earlier than 1.17.6, you need to use
    `XS-Testsuite: autopkgtest` instead.
* tests are declared in `debian/tests/control`.

Please refer to the DEP-8 spec for details on how to declare your tests.

## How exactly is the test suite executed?

Test suites are executed by
[autopkgtest](http://packages.debian.org/autopkgtest). The version of
autopkgtest used to execute the tests is shown in the log file for each test
run.

## How often are test suites executed?

The test suite for a source package will be executed:

* when any package in the dependency chain of its binary packages changes;
* when the package itself changes;
* when 1 month is passed since the test suite was run for the last time.

