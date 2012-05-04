require 'spec_helper'

describe "Variants" do
  context "creating a new variant" do
    it "should allow an admin to create a new variant" do
      product = create(:product_with_option_types, :price => "1.99", :cost_price => "1.00", :weight => "2.5", :height => "3.0", :width => "1.0", :depth => "1.5")

      product.options.each do |option|
        create(:option_value, :option_type => option.option_type)
      end

      visit spree.admin_path
      click_link "Products"
      within('table.index tr:nth-child(2)') { click_link "Edit" }
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
end
