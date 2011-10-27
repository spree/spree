require 'spec_helper'

describe "Customer Details" do
  context "editing an order" do
    before(:each) do
      Factory(:shipping_method, :display_on => "front_end")
      Factory(:order, :completed_at => "2011-02-01 12:36:15")
      Factory(:order, :completed_at => "2010-02-01 17:36:42")
    end

    it "should be able to update customer details for an existing order" do
#      Order.all.each do |order|
#        product = Factory(:product, :name => 'spree t-shirt')
#        order.add_variant(product.master, 2)
#        Factory(:line_item, :order => order, :quantity => 0)
#      end

      visit admin_path
      click_link "Orders"
      within(:css, 'table#listing_orders tr:nth-child(2)') { click_link "Edit" }
      click_link "Customer Details"
    end
  end
end
