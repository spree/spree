require 'spec_helper'


module Spree
  describe ProductsHelper do
    include ProductsHelper
    include BaseHelper
    context "#product_price" do
      let!(:tax_category) { Factory(:tax_category) }
      let!(:product) { Factory(:product, :tax_category => tax_category) }

      it "shows a product's price" do
        Spree::Config.set :show_price_inc_vat => false
        product_price(product).should == "$19.99"
      end

      it "shows a product's price including tax" do
        product.stub :tax_category => tax_category
        tax_category.stub :effective_amount => BigDecimal.new("0.05", 2)
        Spree::Config.set :show_price_inc_vat => true
        product_price(product).should == "$20.99 (inc. VAT)"
      end

    end
  end
end
