# coding: utf-8
require 'spec_helper'

describe "Order Details", js: true do
  let!(:stock_location) { create(:stock_location_with_items) }
  let!(:product) { create(:product, :name => 'spree t-shirt', :price => 20.00) }
  let!(:tote) { create(:product, :name => "Tote", :price => 15.00) }
  let(:order) { create(:order, :state => 'complete', :completed_at => "2011-02-01 12:36:15", :number => "R100") }
  let(:state) { create(:state) }
  let(:shipment) { create(:shipment, :order => order, :stock_location => stock_location) }
  let!(:shipping_method) { create(:shipping_method, :name => "Default") }

  before do
    order.shipments.create({stock_location_id: stock_location.id}, without_protection: true)
    order.contents.add(product.master, 2)
  end

  context 'as Admin' do
    stub_authorization!

    before { visit spree.edit_admin_order_path(order) }

    context "edit order page" do
      it "should allow me to edit order details" do
        page.should have_content("spree t-shirt")
        page.should have_content("$40.00")

        within_row(1) do
          click_icon :edit
          fill_in "quantity", :with => "1"
        end
        click_icon :ok

        within("#order_total") do
          page.should have_content("$20.00")
        end
      end

      it "can add an item to a shipment" do
        select2_search "Tote", :from => Spree.t(:name_or_sku)
        within("table.stock-levels") do
          fill_in "stock_item_quantity", :with => 2
          click_icon :plus
        end

        within("#order_total") do
          page.should have_content("$70.00")
        end
      end

      it "can remove an item from a shipment" do
        page.should have_content("spree t-shirt")

        within_row(1) do
          click_icon :trash
        end

        # Click "ok" on confirmation dialog
        page.driver.browser.switch_to.alert.accept
        page.should_not have_content("spree t-shirt")
      end

      it "can add tracking information" do
        within("table.index tr:nth-child(5)") do
          click_icon :edit
        end
        fill_in "tracking", :with => "FOOBAR"
        click_icon :ok

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
        wait_for_ajax

        page.should have_content("Default")
      end

      context "variant out of stock and not backorderable" do
        before { product.master.stock_items.first.update_column(:backorderable, false) }

        it "displays out of stock instead of add button" do
          select2_search product.name, :from => Spree.t(:name_or_sku)
          within("table.stock-levels") do
            page.should have_content(Spree.t(:out_of_stock))
          end
        end
      end

      context "when two stock locations exist" do
        let!(:london) { create(:stock_location, name: "London") }
        before(:each) { london.stock_items.each { |si| si.adjust_count_on_hand(10) } }

        it "creates a new shipment when adding a variant from the new location" do
          select2_search "Tote", :from => Spree.t(:name_or_sku)
          within("table.stock-levels tr:nth-child(2)") do
            fill_in "stock_item_quantity", :with => 2
            click_icon :plus
          end
          wait_for_ajax
          page.should have_css("#shipment_#{order.shipments.last.id}")
          order.shipments.last.stock_location.should == london
          within "#shipment_#{order.shipments.last.id}" do
            page.should have_content("LONDON")
          end
        end

        context "when two shipments exist" do
          before(:each) do
            select2_search "Tote", :from => Spree.t(:name_or_sku)
            within("table.stock-levels tr:nth-child(2)") do
              fill_in "stock_item_quantity", :with => 2
              click_icon :plus
              wait_for_ajax
            end
          end

          it "updates quantity of the second shipment's items" do
            within("table.stock-contents", :text => tote.name) do
              click_icon :edit
              fill_in "quantity", with: 4
              click_icon :ok
            end

            wait_for_ajax
            page.should have_content("TOTAL: $100.00")
          end

          it "can add tracking information for the second shipment" do
            within("#shipment_#{order.shipments.last.id}") do
              within("tr.show-tracking") do
                click_icon :edit
              end
              wait_for_ajax
              fill_in "tracking", :with => "TRACKING_NUMBER"
              click_icon :ok
            end

            wait_for_ajax
            page.should have_content("Tracking: TRACKING_NUMBER")
          end
        end
      end
    end
  end

  context 'with only read permissions' do
    custom_authorization! do |user|
      can [:admin, :index, :read, :edit], Spree::Order
    end
    it "should not display forbidden links" do
      visit spree.edit_admin_order_path(order)
      page.should_not have_button('cancel')
      page.should_not have_button('Resend')

      # Order Tabs
      page.should_not have_link('Order Details')
      page.should_not have_link('Customer Details')
      page.should_not have_link('Adjustments')
      page.should_not have_link('Payments')
      page.should_not have_link('Return Authorizations')

      # Order item actions
      page.should_not have_css('.delete-item')
      page.should_not have_css('.split-item')
      page.should_not have_css('.edit-item')
      page.should_not have_css('.edit-tracking')

      page.should_not have_css('#add-line-item')
    end
  end

  context 'as Fakedispatch' do
    custom_authorization! do |user|
      # allow dispatch to :admin, :index, and :edit on Spree::Order
      can [:admin, :edit, :index, :read], Spree::Order
      # allow dispatch to :index, :show, :create and :update shipments on the admin
      can [:admin, :manage, :read, :ship], Spree::Shipment
    end

    it 'should not display order tabs or edit buttons without ability' do
      visit spree.edit_admin_order_path(order)
      # Order Form
      page.should_not have_css('.edit-item')
      # Order Tabs
      page.should_not have_link('Order Details')
      page.should_not have_link('Customer Details')
      page.should_not have_link('Adjustments')
      page.should_not have_link('Payments')
      page.should_not have_link('Return Authorizations')
    end

    it "can add tracking information" do
      visit spree.edit_admin_order_path(order)
      within("table.index tr:nth-child(5)") do
        click_icon :edit
      end
      fill_in "tracking", :with => "FOOBAR"
      click_icon :ok
      wait_for_ajax

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
      wait_for_ajax

      page.should have_content("Default")
    end

    it 'can ship' do
      order = create(:order_ready_to_ship)
      order.refresh_shipment_rates
      visit spree.edit_admin_order_path(order)
      click_icon 'arrow-right'
      wait_for_ajax
      within '.shipment-state' do
        page.should have_content('SHIPPED')
      end
    end
  end
end
