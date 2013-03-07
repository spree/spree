require 'spec_helper'

describe "Add items to cart" do
  stub_authorization!

  context "edit order page" do
    let!(:product) { create(:product, :name => 't-shirt', :price => 19.99) }

    before(:each) do
      configure_spree_preferences do |config|
        config.allow_backorders = true
      end
    end

    it "should search product and add it", :js => true do
      visit spree.admin_path
      click_link "Orders"
      click_link "New Order"
      
      select2_search "t-shirt", :from => "Name or SKU (enter at least first 4 characters of product name)"
      within('#add-line-item') { click_on "Add" }
      page.should have_content(product.price)
    end
  end
end
