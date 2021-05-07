require 'spec_helper'

module Spree
  module Filters
    RSpec.describe MoreThanPriceRange do
      let(:price_range) { described_class.new(price: price) }
      let(:price) { Price.new(amount: 50, currency: 'USD') }

      describe '#to_param' do
        it 'returns price range as param' do
          expect(price_range.to_param).to eq('50-0')
        end
      end

      describe '#to_s' do
        it 'returns a formatted price range' do
          expect(price_range.to_s).to eq('More than $50')
        end
      end
    end
  end
end
