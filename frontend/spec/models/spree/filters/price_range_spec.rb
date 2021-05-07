require 'spec_helper'

module Spree
  module Filters
    RSpec.describe PriceRange do
      let(:price_range) { described_class.new(min_price: min_price, max_price: max_price) }

      let(:min_price) { Price.new(amount: 50, currency: 'USD') }
      let(:max_price) { Price.new(amount: 100, currency: 'USD') }

      describe '#to_param' do
        it 'returns price range as param' do
          expect(price_range.to_param).to eq('50-100')
        end
      end

      describe '#to_s' do
        it 'returns a formatted price range' do
          expect(price_range.to_s).to eq('$50 - $100')
        end
      end
    end
  end
end
