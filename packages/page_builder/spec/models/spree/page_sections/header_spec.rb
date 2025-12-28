require 'spec_helper'

describe Spree::PageSections::Header do
  describe '#create' do
    let(:section) { Spree::PageSections::Header.first }

    it 'should be created with default links' do
      expect(section.links.count).to eq(4)
      expect(section.links.map(&:label)).to contain_exactly('Shop All', 'On sale', 'New arrivals', 'Blog')
    end
  end
end
