require 'spec_helper'

module Spree
  module Calculator::Shipping
    describe FlatPercentItemTotal, :type => :model do
      let(:variant1) { build(:variant, :price => 10.11) }
      let(:variant2) { build(:variant, :price => 20.2222) }

      let(:line_item1) { build(:line_item, variant: variant1) }
      let(:line_item2) { build(:line_item, variant: variant2) }

      let(:package) do
        Stock::Package.new(
          build(:stock_location),
          mock_model(Order),
          [
            Stock::Package::ContentItem.new(line_item1, variant1, 2),
            Stock::Package::ContentItem.new(line_item2, variant2, 1)
          ]
        )
      end

      subject { FlatPercentItemTotal.new(:preferred_flat_percent => 10) }

      it "should round result correctly" do
        expect(subject.compute(package)).to eq(4.04)
      end
    end
  end
end
