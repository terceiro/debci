# Deploying debci to your own infrastructure

## Architecture

The following picture represents the debci architecture:

![architecture](architecture.svg)

* The whole system communicates using an AMQP server, in this case `rabbitmq`,
  as a message queue.
* Test jobs are injected into a queue by the `debci-enqueue` command line tool.
* Another command-line tool, called `debci-batch`, can be used to periodically
  inject all test jobs for packages that were recently uploaded, or that had
  one or more of its dependencies updated. It reuses `debci-enqueue` to inject
  each test job.
* test jobs are picked up from the test queue by `debci-worker` daemons. They
  run the tests, and push the results back into a different queue.
* `debci-collector` receives the test results, processes them, feeds the
  database with the results, and produces the HTML pages, atom feeds etc that
  in the web interface.
* Each component (`debci-collector`, `debci-worker`, `rabbitmq`, and the command
  line tools) can live in different hosts if necessary, as long as all of the
  debci components can connect to the `rabbitmq` server.
* You can have as many `debci-worker` nodes in the system as you want, but
  there must be only one `debci-collector`.

## Deployment procedure

Install the debci-collector:

```
$ sudo apt install debci-collector
```

`debci-collector` recommends `rabbitmq-server`, and debci-collector will use a
locally-installed rabbitmq server by default. If you want to use a remote
rabbitmq, you need to add a configuration file with the `.conf` extension to
`/etc/debci/conf.d` with something like this:

```
debci_amqp_server=amqp://MYRABBITMQSERVER
```

Note that if `MYRABBITMQSERVER` is network accessible, it has to have the
proper ACLs configured. Check the rabbitmq documentation for details.

On each worker node, install `apt-cacher-ng` to cache package downloads, and
`debci-worker` itself:

```
$ sudo apt install apt-cacher-ng debci-worker
```

As with `debci-collector`, `debci-worker` will connect to a local rabbitmq by
default. To make it connect to a remote rabbitmq-server you can do the same as
above.

Note that when first installed, `debci-worker` will first build a testbed (a
chroot, container, or a virtual machine image, depening on the selected
backend), and only after that is finished the worker will be able to start
processing test jobs.

## Submitting test jobs

On any host that can connect to `rabbitmq-server`, first install `debci`:

```
$ sudo apt install debci
```

As usual, you will prompted for the address of the AMQP server. If the
`rabbitmq-server` is on the same host, just leave it blank.

Say you want to run the tests for the `ruby-defauts` package. It is as easy as

```
$ debci enqueue ruby-defaults
```

## Scheduling job submission

By default, `debci` will not submit any jobs. You need to decide how, and how
often, you want to submit jobs. A simple way of doing that is using `cron`.

**Example 1: schedule tests for a set of packages once a day**

```bash
# /etc/cron.d/debci
0 7 * * * debci debci enqueue rake rubygems-integration ruby-defaults
```

**Example 2: schedule tests for all pending packages evety 4 hours:**

```bash
# /etc/cron.d/debci
17 */4 * * * debci debci batch
```

You can also automate calls to `debci enqueue` in any other way you want.

## Multiple worker processes per node

If you have worker nodes that have lots of CPUs and a large amount of RAM
available you can run multiple worker daemons at once.

*TODO*

## Setting up the LXC backend

*TODO*
