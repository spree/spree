require 'spec_helper'

describe "Order Details" do
  context "edit order page" do
    it "should allow me to edit order details", :js => true do
      @configuration ||= Spree::AppConfiguration.find_or_create_by_name("Default configuration")
      Spree::Config.set :allow_backorders => true
      order = Factory(:order, :completed_at => "2011-02-01 12:36:15", :number => "R100")
      product = Factory(:product, :name => 'spree t-shirt', :on_hand => 5)
      order.add_variant(product.master, 2)
      order.inventory_units.each do |iu|
        iu.update_attribute_without_callbacks('state', 'sold')
      end

      visit spree.admin_path
      click_link "Orders"

      within('table#listing_orders tbody tr:nth-child(1)') { click_link "R100" }
      page.should have_content("spree t-shirt")
      page.should have_content("$39.98")
      click_link "Edit"
      fill_in "order_line_items_attributes_0_quantity", :with => "1"
      page.should have_content("Total: $19.99")
    end
  end
end
