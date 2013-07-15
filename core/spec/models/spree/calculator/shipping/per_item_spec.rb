require 'spec_helper'

module Spree
  module Calculator::Shipping
    describe PerItem do
      let(:variant1) { build(:variant) }
      let(:variant2) { build(:variant) }
      let(:package) { double(Stock::Package,
                           order: mock_model(Order),
                           contents: [Stock::Package::ContentItem.new(variant1, 5),
                                      Stock::Package::ContentItem.new(variant2, 3)]) }

      subject { PerItem.new(:preferred_amount => 10) }

      it "correctly calculates per item shipping" do
        subject.compute(package).to_f.should == 80 # 5 x 10 + 3 x 10
      end
    end
  end
end
