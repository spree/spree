# encoding: utf-8
require 'spec_helper'

describe "Variants" do
  stub_authorization!

  let(:product) { create(:product_with_option_types, :price => "1.99", :cost_price => "1.00", :weight => "2.5", :height => "3.0", :width => "1.0", :depth => "1.5") }

  context "creating a new variant" do
    it "should allow an admin to create a new variant" do
      product.options.each do |option|
        create(:option_value, :option_type => option.option_type)
      end

      visit spree.admin_path
      click_link "Products"
      within_row(1) { click_icon :edit }
      click_link "Variants"
      click_on "New Variant"
      find('input#variant_price').value.should == "1.99"
      find('input#variant_cost_price').value.should == "1.00"
      find('input#variant_weight').value.should == "2.50"
      find('input#variant_height').value.should == "3.00"
      find('input#variant_width').value.should == "1.00"
      find('input#variant_depth').value.should == "1.50"
    end
  end

  context "listing variants" do
    context "currency displaying" do
      context "using Russian Rubles" do
        before do
          Spree::Config[:currency] = "RUB"
        end

        let!(:variant) do
          create(:variant, :product => product, :price => 19.99)
        end

        # Regression test for #2737
        context "uses руб as the currency symbol" do
          it "on the products listing page" do
            visit spree.admin_product_variants_path(product)
            within_row(1) { page.should have_content("руб19.99") }
          end
        end
      end
    end
  end
end
