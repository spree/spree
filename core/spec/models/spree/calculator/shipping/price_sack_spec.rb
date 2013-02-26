require 'spec_helper'

module Spree
  module Calculator::Shipping
    describe PriceSack do
      let(:variant1) { build(:variant, :price => 2) }
      let(:variant2) { build(:variant, :price => 2) }
      let(:content_items) { [Stock::Package::ContentItem.new(variant1, 1),
                             Stock::Package::ContentItem.new(variant2, 1)] }
      subject { PriceSack.new(:preferred_minimal_amount => 5,
                              :preferred_normal_amount => 10,
                              :preferred_discount_amount => 1) }

      it "uses normal amount when below minimal" do
        subject.compute(content_items).should == subject.preferred_normal_amount
      end

      it 'uses discount amount when over minimal' do
        variant1.stub(:price => 10)
        subject.compute(content_items).should == subject.preferred_discount_amount
      end
    end
  end
end
