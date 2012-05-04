require 'spec_helper'

module Spree
  describe ProductsHelper do
    include ProductsHelper

    context "#variant_price_diff" do
      before do
        @product = create(:product)
        @variant = create(:variant, :product => @product)
      end

      it "should be correct positive value when variant is more than master" do
        @product.price = 10
        @variant.price = 15
        helper.variant_price_diff(@variant).should == "(Add: $5.00)"
      end

      it "should be nil when variant is same as master" do
        @product.price = 10
        @variant.price = 10
        helper.variant_price_diff(@variant).should be_nil
      end

      it "should be correct negative value when variant is less than master" do
        @product.price = 15
        @variant.price = 10
        helper.variant_price_diff(@variant).should == "(Subtract: $5.00)"
      end
    end
  end
end
