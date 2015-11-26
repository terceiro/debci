require 'debci'

describe Debci do

  it 'resets config object after config!' do
    c1 = Debci.config
    Debci.config!(foo: 'bar')
    c2 = Debci.config

    expect(c2).to_not be(c1)
  end

  it 'can set configuration variables' do
    Debci.config!(arch: 'arm64')
    expect(Debci.config.packages_dir).to match('arm64')
  end

  it 'has a blacklist' do
    expect(Debci.blacklist).to respond_to(:include?)
  end

  it 'resets blacklist object when configuration is changed' do
    b1 = Debci.blacklist; Debci.config!(foo: 'bar'); b2 = Debci.blacklist
    expect(b2).to_not be(b1)
  end

end
