require 'debci/package'
require 'debci/html/cli'

describe Debci::HTML::CLI do
  it 'calls update on update' do
    expect(Debci::HTML).to receive(:update)
    Debci::HTML::CLI.new.update
  end

  it 'calls update_package on update-pakckage' do
    pkg = Debci::Package.create!(name: 'foo')
    expect(Debci::HTML).to receive(:update_package).with(pkg, nil, nil)
    Debci::HTML::CLI.new.update_package('foo')
  end
end
