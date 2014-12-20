require 'spec_helper'

module Spree
  module Calculator::Shipping
    describe FlatPercentItemTotal, :type => :model do

      let(:line_item1) { build(:line_item, :price => 10.11) }
      let(:line_item2) { build(:line_item, :price => 20.2222) }

      let(:package) do
        build(:stock_package, line_item_contents: { line_item1 => 2, line_item2 => 1 })
      end

      subject { FlatPercentItemTotal.new(:preferred_flat_percent => 10) }

      it "should round result correctly" do
        expect(subject.compute(package)).to eq(4.04)
      end
    end
  end
end
