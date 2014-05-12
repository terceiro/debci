# The debci Ruby API

The main entry point of the API is the {Debci::Repository} class. It will allow
you to find objects representing specific packages, and from there to test run
results.

## Accessing packages

```
require 'debci'
repository = Debci::Repository.new
```

With a package object, you can obtain {Debci::Package} objects:

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

The `news` method will return a news feed for that package, listing test runs
where the package status changed from `pass` to `fail` or the other way around.

```
news = package.news
news.each do |item|
  puts item.headline
end
```

See the documentation for the {Debci::Package} class for more information.
