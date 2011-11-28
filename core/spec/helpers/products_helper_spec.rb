require 'spec_helper'


module Spree
  describe ProductsHelper do
    include ProductsHelper
    include BaseHelper
    context "#product_price" do
      let(:product) { Factory(:product) }

      it "shows a product's price" do
        Spree::Config.set :show_price_inc_vat => false
        product_price(product).should == "$19.99"
      end

      it "shows a product's price including tax" do
        Spree::Config.set :show_price_inc_vat => true
        product_price(product).should == "$20.99 (inc. VAT)"
      end

    end
  end
end
