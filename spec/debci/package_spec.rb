require 'debci/package'

describe Debci::Package do

  let(:repository) { double }

  let(:package) do
    Debci::Package.new('rake', repository)
  end

  it 'queries repository for architectures' do
    repository.stub(:architectures_for).with(package).and_return(['amd64', 'i386'])
    expect(package.architectures).to eq(['amd64', 'i386'])
  end

  it 'queries repository for suites' do
    repository.stub(:suites_for).with(package).and_return(['unstable', 'experimental'])
    expect(package.suites).to eq(['unstable', 'experimental'])
  end

  it 'queries repository for status' do
    status = double
    repository.stub(:status_for).with(package).and_return(status)
    expect(package.status).to be(status)
  end

  it 'queries repository for news' do
    news = double
    repository.stub(:news_for).with(package).and_return(news)
    expect(package.news).to be(news)
  end

  it 'converts to string' do
    expect(String(package)).to eq(package.name)
  end

end
