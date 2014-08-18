require 'json'

def fix(entry)
  if entry['date'] =~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/ && entry['run_id']
    entry['date'] = entry['run_id'].sub(/([0-9][0-9][0-9][0-9])([0-9][0-9])([0-9][0-9])_([0-9][0-9])([0-9][0-9])([0-9][0-9])/, '\1-\2-\3 \4:\5:\6')
  end
end

to_fix = IO.popen(['grep', '-rl', '"date": "[0-9][0-9]:[0-9][0-9]:[0-9][0-9]"', 'data/packages/'])
to_fix.each_line do |line|
  file = line.strip

  data = JSON.load(File.read(file))

  if File.basename(file) == 'history.json'
    data.each do |entry|
      fix(entry)
    end
  else
    fix(data)
  end

  File.open(file, 'w') do |f|
    f.write(JSON.pretty_generate(data))
  end
end

system('./bin/debci generate-index')
