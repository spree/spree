require 'spec_helper'

module Spree
  module Filters
    RSpec.describe QuantifiedPriceRange do
      let(:price_range) { described_class.new(price: price, quantifier: quantifier) }
      let(:price) { Price.new(amount: 50, currency: 'USD') }

      context 'when the quantifier is less_than' do
        let(:quantifier) { :less_than }

        describe '#to_param' do
          it 'returns price range as param' do
            expect(price_range.to_param).to eq('0-50')
          end
        end

        describe '#to_s' do
          it 'returns a formatted price range' do
            expect(price_range.to_s).to eq('Less than $50')
          end
        end
      end

      context 'when the quantifier is more_than' do
        let(:quantifier) { :more_than }

        describe '#to_param' do
          it 'returns price range as param' do
            expect(price_range.to_param).to eq('50-Infinity')
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
end
