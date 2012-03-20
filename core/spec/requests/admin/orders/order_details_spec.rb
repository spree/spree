# coding: utf-8
require 'spec_helper'

describe "Order Details" do
  context "edit order page" do

    before do
      reset_spree_preferences do |config|
        config.allow_backorders = true
      end
    end

    after(:each) { I18n.reload! }

    let(:product) { Factory(:product, :name => 'spree t-shirt', :on_hand => 5, :price => 19.99) }
    let(:order) { Factory(:order, :completed_at => "2011-02-01 12:36:15", :number => "R100") }

    it "should allow me to edit order details", :js => true do
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
      click_button "Continue"
      page.should have_content("Total: $19.99")
    end

    it "should render details properly" do
      order.state = :complete
      order.save!

      visit spree.edit_admin_order_path(order)

      within "#sidebar" do
        find("#order_number").text.should == "Order #R100"
        find("#order_status").text.should == "Status: complete"
        find("#shipment_status").text.should == "Shipment: none"
        find("#payment_status").text.should == "Payment: none"
      end

      I18n.backend.store_translations I18n.locale,
        :shipment_state => { :missing => 'some text' },
        :payment_states => { :missing => 'other text' },
        :number => { :currency => { :format => {
          :format => "%n&mdash;%u",
          :unit => "&pound;"
        }}}

      visit spree.edit_admin_order_path(order)

      within "#sidebar" do
        # beware - the dash before pound is really em dash character '—'
        find("#order_total").text.should == "#{I18n.t(:total)}: 0.00—£"
        find("#shipment_status").text.should == "#{I18n.t(:shipment)}: some text"
        find("#payment_status").text.should == "#{I18n.t(:payment)}: other text"
      end

    end
  end
end
