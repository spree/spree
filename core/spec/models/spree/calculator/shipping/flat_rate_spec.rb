require 'spec_helper'

module Spree
  module Calculator::Shipping
    describe FlatRate do
      let(:variant1) { build(:variant) }
      let(:variant2) { build(:variant) }

      let(:package) do
        Stock::Package.new(
          build(:stock_location),
          mock_model(Order),
          [
            Stock::Package::ContentItem.new(variant1, 2),
            Stock::Package::ContentItem.new(variant2, 1)
          ]
        )
      end

      subject { Calculator::Shipping::FlatRate.new(:preferred_amount => 4.00) }

      it 'always returns the same rate' do
        expect(subject.compute(package)).to eql 4.00
      end
    end
  end
end
