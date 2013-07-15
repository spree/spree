require 'spec_helper'

module Spree
  module Calculator::Shipping
    describe FlatPercentItemTotal do
      let(:variant1) { build(:variant, :price => 10.11) }
      let(:variant2) { build(:variant, :price => 20.2222) }
      let(:package) { double(Stock::Package,
                           order: mock_model(Order),
                           contents: [Stock::Package::ContentItem.new(variant1, 2),
                                      Stock::Package::ContentItem.new(variant2, 1)]) }

      subject { FlatPercentItemTotal.new(:preferred_flat_percent => 10) }

      it "should round result correctly" do
        subject.compute(package).should == 4.04
      end
    end
  end
end
