require 'debci/app'

describe Debci::App do
  context 'pagination' do
    it 'links to the last page' do
      pages = Debci::App.get_page_range(1, 30)
      expect(pages).to eq([1, 2, 3, 4, 5, 6, nil, 30])
    end
    it 'links to the first page' do
      pages = Debci::App.get_page_range(30, 30)
      expect(pages).to eq([1, nil, 25, 26, 27, 28, 29, 30])
    end

    it 'links to first and last page' do
      pages = Debci::App.get_page_range(15, 30)
      expect(pages).to eq([1, nil, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, nil, 30])
    end
    it 'links to all pages when there are few of them' do
      pages = Debci::App.get_page_range(1, 5)
      expect(pages).to eq([1, 2, 3, 4, 5])
    end
    it 'links to all pages when on page 6 of 11' do
      pages = Debci::App.get_page_range(6, 11)
      expect(pages).to eq([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
    end
  end
end
