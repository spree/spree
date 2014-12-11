# coding: utf-8
require 'spec_helper'

describe "Order Details", type: :feature, js: true do
  let!(:stock_location) { create(:stock_location_with_items) }
  let!(:product) { create(:product, :name => 'spree t-shirt', :price => 20.00) }
  let!(:tote) { create(:product, :name => "Tote", :price => 15.00) }
  let(:order) { create(:order, :state => 'complete', :completed_at => "2011-02-01 12:36:15", :number => "R100") }
  let(:state) { create(:state) }
  let(:shipment) { create(:shipment, :order => order, :stock_location => stock_location) }
  let!(:shipping_method) { create(:shipping_method, :name => "Default") }

  before do
    order.shipments.create(stock_location_id: stock_location.id)
    order.contents.add(product.master, 2)
  end

  context 'as Admin' do
    stub_authorization!

    before { visit spree.edit_admin_order_path(order) }

    context "edit order page" do
      it "should allow me to edit order details" do
        expect(page).to have_content("spree t-shirt")
        expect(page).to have_content("$40.00")

        within_row(1) do
          click_icon :edit
          fill_in "quantity", :with => "1"
        end
        click_icon :ok

        within("#order_total") do
          expect(page).to have_content("$20.00")
        end
      end

      it "can add an item to a shipment" do
        select2_search "Tote", :from => Spree.t(:name_or_sku)
        within("table.stock-levels") do
          fill_in "stock_item_quantity", :with => 2
          click_icon :plus
        end

        within("#order_total") do
          expect(page).to have_content("$70.00")
        end
      end

      it "can remove an item from a shipment" do
        expect(page).to have_content("spree t-shirt")

        within_row(1) do
          accept_alert do
            click_icon :trash
          end
        end

        # Click "ok" on confirmation dialog
        expect(page).not_to have_content("spree t-shirt")
      end

      # Regression test for #3862
      it "can cancel removing an item from a shipment" do
        expect(page).to have_content("spree t-shirt")

        within_row(1) do
          # Click "cancel" on confirmation dialog
          dismiss_alert do
            click_icon :trash
          end
        end

        expect(page).to have_content("spree t-shirt")
      end

      it "can add tracking information" do
        within(".show-tracking") do
          click_icon :edit
        end
        fill_in "tracking", :with => "FOOBAR"
        click_icon :ok

        expect(page).not_to have_css("input[name=tracking]")
        expect(page).to have_content("Tracking: FOOBAR")
      end

      it "can change the shipping method" do
        order = create(:completed_order_with_totals)
        visit spree.edit_admin_order_path(order)
        within("table.index tr.show-method") do
          click_icon :edit
        end
        select2 "Default", :from => "Shipping Method"
        click_icon :ok

        expect(page).not_to have_css('#selected_shipping_rate_id')
        expect(page).to have_content("Default")
      end

      it "can assign a back-end only shipping method" do
        create(:shipping_method, name: "Backdoor", display_on: "back_end")
        order = create(
          :completed_order_with_totals,
          shipping_method_filter: Spree::ShippingMethod::DISPLAY_ON_FRONT_AND_BACK_END
        )
        visit spree.edit_admin_order_path(order)
        within("table.index tr.show-method") do
          click_icon :edit
        end
        select2 "Backdoor", from: "Shipping Method"
        click_icon :ok

        expect(page).not_to have_css('#selected_shipping_rate_id')
        expect(page).to have_content("Backdoor")
      end

      it "will show the variant sku" do
        order = create(:completed_order_with_totals)
        visit spree.edit_admin_order_path(order)
        sku = order.line_items.first.variant.sku
        expect(page).to have_content("SKU: #{sku}")
      end

      context "variant out of stock and not backorderable" do
        before { product.master.stock_items.first.update_column(:backorderable, false) }

        it "displays out of stock instead of add button" do
          select2_search product.name, :from => Spree.t(:name_or_sku)
          within("table.stock-levels") do
            expect(page).to have_content(Spree.t(:out_of_stock))
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
          expect(page).to have_css("#shipment_#{order.shipments.last.id}")
          expect(order.shipments.last.stock_location).to eq(london)
          within "#shipment_#{order.shipments.last.id}" do
            expect(page).to have_content("LONDON")
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

            # poltergeist and selenium disagree on the existance of this space
            expect(page).to have_content(/TOTAL: ?\$100\.00/)
          end

          it "can add tracking information for the second shipment" do
            within("#shipment_#{order.shipments.last.id}") do
              within("tr.show-tracking") do
                click_icon :edit
              end

              fill_in "tracking", :with => "TRACKING_NUMBER"
              click_icon :ok
            end

            expect(page).not_to have_css("input[name=tracking]")
            expect(page).to have_content("Tracking: TRACKING_NUMBER")
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
            select2 "United States of America", :from => "Country"
            click_icon :refresh

            click_link "Order Details"

            within("#shipment_#{order.shipments.last.id}") do
              within("tr.show-method") do
                click_icon :edit
              end
              select2 "Default", :from => "Shipping Method"
            end
            click_icon :ok

            expect(page).not_to have_css('#selected_shipping_rate_id')
            expect(page).to have_content("Default")
          end
        end
      end

      context "with special_instructions present" do
        let(:order) { create(:order, :state => 'complete', :completed_at => "2011-02-01 12:36:15", :number => "R100", :special_instructions => "Very special instructions here") }
        it "will show the special_instructions" do
          visit spree.edit_admin_order_path(order)
          expect(page).to have_content("Very special instructions here")
        end
      end

      context "variant doesn't track inventory" do
        before do
          tote.master.update_column :track_inventory, false
          # make sure there's no stock level for any item
          tote.master.stock_items.update_all count_on_hand: 0, backorderable: false
        end

        it "adds variant to order just fine"  do
          select2_search tote.name, :from => Spree.t(:name_or_sku)

          within("table.stock-levels") do
            fill_in "stock_item_quantity", :with => 1
            click_icon :plus
          end

          within(".stock-contents") do
            expect(page).to have_content(tote.name)
          end
        end
      end
    end
  end

  context 'with only read permissions' do
    before do
      allow_any_instance_of(Spree::Admin::BaseController).to receive(:spree_current_user).and_return(nil)
    end

    custom_authorization! do |user|
      can [:admin, :index, :read, :edit], Spree::Order
    end
    it "should not display forbidden links" do
      visit spree.edit_admin_order_path(order)
      expect(page).not_to have_button('cancel')
      expect(page).not_to have_button('Resend')

      # Order Tabs
      expect(page).not_to have_link('Order Details')
      expect(page).not_to have_link('Customer Details')
      expect(page).not_to have_link('Adjustments')
      expect(page).not_to have_link('Payments')
      expect(page).not_to have_link('Return Authorizations')

      # Order item actions
      expect(page).not_to have_css('.delete-item')
      expect(page).not_to have_css('.split-item')
      expect(page).not_to have_css('.edit-item')
      expect(page).not_to have_css('.edit-tracking')

      expect(page).not_to have_css('#add-line-item')
    end
  end

  context 'as Fakedispatch' do
    custom_authorization! do |user|
      # allow dispatch to :admin, :index, and :edit on Spree::Order
      can [:admin, :edit, :index, :read], Spree::Order
      # allow dispatch to :index, :show, :create and :update shipments on the admin
      can [:admin, :manage, :read, :ship], Spree::Shipment
    end

    before do
      allow_any_instance_of(Spree::Api::BaseController).to receive_messages :try_spree_current_user => Spree.user_class.new
    end

    it 'should not display order tabs or edit buttons without ability' do
      visit spree.edit_admin_order_path(order)

      # Order Form
      expect(page).not_to have_css('.edit-item')
      # Order Tabs
      expect(page).not_to have_link('Order Details')
      expect(page).not_to have_link('Customer Details')
      expect(page).not_to have_link('Adjustments')
      expect(page).not_to have_link('Payments')
      expect(page).not_to have_link('Return Authorizations')
    end

    it "can add tracking information" do
      visit spree.edit_admin_order_path(order)
      within("table.index tr:nth-child(5)") do
        click_icon :edit
      end
      fill_in "tracking", :with => "FOOBAR"
      click_icon :ok

      expect(page).not_to have_css("input[name=tracking]")
      expect(page).to have_content("Tracking: FOOBAR")
    end

    it "can change the shipping method" do
      order = create(:completed_order_with_totals)
      visit spree.edit_admin_order_path(order)
      within("table.index tr.show-method") do
        click_icon :edit
      end
      select2 "Default", :from => "Shipping Method"
      click_icon :ok

      expect(page).not_to have_css('#selected_shipping_rate_id')
      expect(page).to have_content("Default")
    end

    it 'can ship' do
      order = create(:order_ready_to_ship)
      order.refresh_shipment_rates
      visit spree.edit_admin_order_path(order)
      click_icon 'arrow-right'
      wait_for_ajax
      within '.shipment-state' do
        expect(page).to have_content('SHIPPED')
      end
    end
  end
end
