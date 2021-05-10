require 'spec_helper'

RSpec.describe Spree::Filters::Price do
  let(:price) { described_class.new(amount: 50, currency: 'USD') }

  describe '#to_i' do
    it 'returns price amount' do
      expect(price.to_i).to eq(50)
    end
  end

  describe '#to_s' do
    it 'returns a formatted price' do
      expect(price.to_s).to eq('$50')
    end
  end
end
