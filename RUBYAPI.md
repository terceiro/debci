# The debci Ruby API

The main entry point of the API is the {Debci::Repository} class. It will allow
you to find objects representing specific packages, and from there to test run
results.

## Accessing packages

```
require 'debci'
repository = Debci::Repository.new
```

With a repository object, you can obtain {Debci::Package} objects:

```
package = repository.find_package('rails-3.2')
```

## Obtaining data for a given package

With a Debci:Package object, you can obtain the current status with the
`status` method. This method will return a table with architectures on rows,
suites on columns, and a status object in each cell.

```
status_table = package.status
```

### Getting package news

The `news` method will return a news feed for that package, listing test runs
where the package status changed from `pass` to `fail` or the other way around.

```
news = package.news

news.each do |item|
  puts item.headline
end
```

### Finding package failures (Overall Status)

The `failures` method returns an array of suite/architectures that the package
is failing. If there are no failures, nothing is returned.

```
failures = package.failures

if failures
  puts failures
else
  puts 'Passing everywhere'
end
```

### Getting test history

The `history` method obtains a package`s test history on a specific
suite and architecture. This method will return an array of {Debci::Status}
objects where each object represents one test entry.

```
history = package.history('unstable', 'amd64')

puts package.name

history.each do |entry|
  puts 'Version: ' + entry.version
  puts 'Date: ' + entry.date
  puts 'Status: ' + entry.status
end
```
See the documentation for the {Debci::Package} class for more information.
