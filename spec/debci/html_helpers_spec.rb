require 'debci/html_helpers'

describe Debci::HTMLHelpers do
  include Debci::HTMLHelpers
  FakeTest = Struct.new(:trigger, :pin_packages, keyword_init: true) do
    def pinned?
      pin_packages && !pin_packages.empty?
    end
  end

  context 'filesize' do
    it 'returns nil on missing files' do
      expect(filesize('/path/to/improbable/file', '%s')).to be_nil
    end
    it 'formats 0' do
      expect(filesize('/dev/null', '%s')).to eq("0 Bytes")
    end
  end

  let(:test) { FakeTest.new }

  context 'title_test_trigger_pin' do
    it 'returns empty string for no data' do
      expect(title_test_trigger_pin(test)).to eq('')
    end
    it 'adds trigger if any' do
      test.trigger = "foo"
      expect(title_test_trigger_pin(test)).to match("Trigger:\nfoo")
    end
    it 'adds pin_packages if any' do
      test.pin_packages = [["src:rake", "unstable"]]
      expect(title_test_trigger_pin(test)).to eq("Pinned packages:\nsrc:rake from unstable\n")
    end
  end

  context 'expanding pin_packages' do
    it 'expands no pin_packages to nil' do
      expect(expand_pin_packages(test)).to eq([])
    end

    it 'expands pin_packages with one' do
      test.pin_packages = [["src:rake", "unstable"]]
      expect(expand_pin_packages(test)).to eq(["src:rake from unstable"])
    end

    it 'expands pin_packages with multiple' do
      test.pin_packages = [["src:rake,src:ruby", "unstable"]]
      expect(expand_pin_packages(test)).to eq(["src:rake from unstable", "src:ruby from unstable"])
    end

    it 'expands pin_packages entry with multiple packages' do
      test.pin_packages = [["src:rake", "src:ruby", "unstable"]]
      expect(expand_pin_packages(test)).to eq(["src:rake from unstable", "src:ruby from unstable"])
    end

    it 'expands pin_packages with invalid entry' do
      test.pin_packages = [[nil, "unstable"]]
      expect(expand_pin_packages(test)).to be_an(Array)
    end
  end
end
