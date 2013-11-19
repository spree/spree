require 'spec_helper'

module Spree
  module Calculator::Shipping
    describe PerItem do
      let(:variant1) { build(:variant) }
      let(:variant2) { build(:variant) }

      let(:line_item1) { build(:line_item, variant: variant1) }
      let(:line_item2) { build(:line_item, variant: variant2) }

      let(:package) do
        double(
          Stock::Package,
          order: mock_model(Order),
          contents: [
            Stock::Package::ContentItem.new(line_item1, variant1, 5),
            Stock::Package::ContentItem.new(line_item2, variant2, 3)
          ]
        )
      end

      subject { PerItem.new(:preferred_amount => 10) }

      it "correctly calculates per item shipping" do
        subject.compute(package).to_f.should == 80 # 5 x 10 + 3 x 10
      end
    end
  end
end
