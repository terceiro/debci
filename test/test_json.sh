#!/bin/sh

. $(dirname $0)/test_helper.sh

test_valid_json() {
  debci batch

  ruby <<EOF || fail 'found invalid JSON files'
    require 'json'
    failed = 0
    Dir.glob(File.join('${debci_data_basedir}', '**/*.json')).each do |file|
      begin
        JSON.parse(File.read(file))
      rescue JSON::ParserError => exc
        puts "#{file} contains invalid JSON: #{exc.message}"
        failed += 1
      end
    end
    exit(failed)
EOF
}

. shunit2
