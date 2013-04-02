# coding: utf-8
require 'spec_helper'

describe "Order Details" do
  stub_authorization!

  context "edit order page", :js => true do
    after(:each) { I18n.reload! }

    let!(:stock_location) { create(:stock_location_with_items) }
    let!(:product) { create(:product, :name => 'spree t-shirt', :price => 20.00) }
    let!(:tote) { create(:product, :name => "Tote", :price => 15.00) }
    let(:order) { create(:order, :state => 'complete', :completed_at => "2011-02-01 12:36:15", :number => "R100") }
    let(:shipment) { create(:shipment, :order => order, :stock_location => stock_location) }

    before(:each) do
      configure_spree_preferences do |config|
        config.allow_backorders = true
      end
      create(:country)
      create(:state, :country => create(:country))
      create(:shipping_method, :name => "Default")
      order.shipments.create({stock_location_id: stock_location.id}, without_protection: true)
      order.contents.add(product.master, 2)
    end

    it "should allow me to edit order details" do
      visit spree.edit_admin_order_path(order)
      page.should have_content("spree t-shirt")
      page.should have_content("$40.00")

      within_row(1) do
        click_icon :edit
        fill_in "quantity", :with => "1"
      end
      click_icon :ok
      sleep 1
      page.should have_content("Total: $20.00")
    end

    it "can add an item to a shipment" do
      visit spree.edit_admin_order_path(order)

      select2_search "Tote", :from => I18n.t(:name_or_sku)
      within("table.stock-levels") do
        fill_in "stock_item_quantity", :with => 2
        click_icon :plus
      end
      sleep 1
      page.should have_content("Total: $70.00")
    end

    it "can remove an item from a shipment" do
      visit spree.edit_admin_order_path(order)
      page.should have_content("spree t-shirt")

      within_row(1) do
        click_icon :trash
      end
      sleep 1
      page.should_not have_content("spree t-shirt")
    end

    it "can add tracking information" do
      visit spree.edit_admin_order_path(order)
      within("table.index tr:nth-child(5)") do
        click_icon :edit
      end
      fill_in "tracking", :with => "FOOBAR"
      click_icon :ok
      sleep 1
      page.should have_content("Tracking: FOOBAR")
    end

    it "can change the shipping method" do
      order = create(:completed_order_with_totals)
      visit spree.edit_admin_order_path(order)
      within("table.index tr.show-method") do
        click_icon :edit
      end
      select2 "Default", :from => "Shipping Method"
      click_icon :ok
      sleep 1
      page.should have_content("Default:")
    end

    context "when two stock locations exist" do
      let!(:london) { create(:stock_location, name: "London") }
      before(:each) { london.stock_items.each { |si| si.adjust_count_on_hand(10) } }

      it "creates a new shipment when adding a variant from the new location" do
        visit spree.edit_admin_order_path(order)

        select2_search "Tote", :from => I18n.t(:name_or_sku)
        within("table.stock-levels tr:nth-child(2)") do
          fill_in "stock_item_quantity", :with => 2
          click_icon :plus
        end
        sleep 1
        page.all("table.stock-contents").count.should == 2
        order.shipments.last.stock_location.should == london
        page.should have_content("London")
      end

      context "when two shipments exist" do
        before(:each) do
          visit spree.edit_admin_order_path(order)

          select2_search "Tote", :from => I18n.t(:name_or_sku)
          within("table.stock-levels tr:nth-child(2)") do
            fill_in "stock_item_quantity", :with => 2
            click_icon :plus
          end
          sleep 1
          page.all("table.stock-contents").count.should == 2
        end

        it "can increase quantity of the second shipment's items" do
          within("table.stock-contents:nth-child(2)") do
            within("tbody tr:nth-child(1)") do
              click_icon :edit
              fill_in "quantity", with: 4
            end
            click_icon :ok
          end

          sleep 1
          page.should have_content("Total: $100.00")
        end

        it "can decrease quantity of the second shipment's items" do
          within("table.stock-contents:nth-child(2)") do
            within("tbody tr:nth-child(1)") do
              click_icon :edit
              fill_in "quantity", with: 1
            end
            click_icon :ok
          end

          sleep 1
          page.should have_content("Total: $55.00")
        end

        it "can add tracking information for the second shipment" do
          within("table.stock-contents:nth-child(2)") do
            within("tr.show-tracking") do
              click_icon :edit
            end
            fill_in "tracking", :with => "TRACKING_NUMBER"
          end
          click_icon :ok
          sleep 1
          page.should have_content("Tracking: TRACKING_NUMBER")
        end

        it "can change the second shipment's shipping method" do
          click_link "Customer Details"

          check "order_use_billing"
          fill_in "order_bill_address_attributes_firstname", :with => "Joe"
          fill_in "order_bill_address_attributes_lastname", :with => "User"
          fill_in "order_bill_address_attributes_address1", :with => "7735 Old Georgetown Road"
          fill_in "order_bill_address_attributes_address2", :with => "Suite 510"
          fill_in "order_bill_address_attributes_city", :with => "Bethesda"
          fill_in "order_bill_address_attributes_zipcode", :with => "20814"
          fill_in "order_bill_address_attributes_phone", :with => "301-444-5002"
          select2 "Alabama", :from => "State"
          select2 "United States of Foo", :from => "Country"
          click_icon :refresh

          click_link "Order Details"

          within("table.stock-contents:nth-child(2)") do
            within("tr.show-method") do
              click_icon :edit
            end
            select2 "Default", :from => "Shipping Method"
          end
          click_icon :ok
          sleep 1
          page.should have_content("Default:")
        end
      end
    end
  end
end
