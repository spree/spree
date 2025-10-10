require 'spec_helper'

describe Spree::Pages::Homepage do
  describe '#create' do
    let(:page) { Spree::Pages::Homepage.first }

    it 'should be created with default sections' do
      expect(page.sections.count).to eq(4)
      expect(page.sections.map(&:display_name)).to contain_exactly(
        'Image With Text',
        'On sale - Featured Taxon',
        'New arrivals - Featured Taxon',
        'Image With Text'
      )
    end
  end
end
