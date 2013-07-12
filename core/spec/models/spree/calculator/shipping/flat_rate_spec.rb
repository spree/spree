require 'spec_helper'

module Spree
  module Calculator::Shipping
    describe FlatRate do
      let(:variant1) { build(:variant) }
      let(:variant2) { build(:variant) }
      let(:package) { double(Stock::Package,
                           order: mock_model(Order),
                           contents: [Stock::Package::ContentItem.new(variant1, 2),
                                      Stock::Package::ContentItem.new(variant2, 1)]) }

      subject { Calculator::Shipping::FlatRate.new(:preferred_amount => 4.00) }

      it 'always returns the same rate' do
        subject.compute(package)
      end
    end
  end
end
