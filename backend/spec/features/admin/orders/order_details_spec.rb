require 'spec_helper'

describe 'Order Details', type: :feature, js: true do
  let!(:stock_location) { create(:stock_location_with_items) }
  let!(:product) { create(:product, name: 'spree t-shirt', price: 20.00) }
  let!(:store) { create(:store) }
  let(:order) { create(:order, state: 'complete', completed_at: '2011-02-01 12:36:15', number: 'R100', store_id: store.id) }
  let(:state) { create(:state) }

  before do
    create(:shipping_method, name: 'Default')
    order.shipments.create!(stock_location_id: stock_location.id)
    Spree::Cart::AddItem.call(order: order, variant: product.master, quantity: 2)
  end

  context 'as Admin' do
    stub_authorization!

    context 'store edit page' do
      let!(:new_store) { create(:store) }

      before do
        product.master.stock_items.first.update_column(:count_on_hand, 100)
        visit spree.store_admin_order_path(order)
      end

      it 'displays select with current order store name' do
        expect(page).to have_content(store.name)
      end

      it 'after selecting a store assings a new store to order' do
        select2 new_store.name, from: 'Store', match: :first
        find('[name=button]').click

        expect(page).to have_content(new_store.name)
      end
    end

    context 'cart edit page' do
      before do
        product.master.stock_items.first.update_column(:count_on_hand, 100)
        visit spree.cart_admin_order_path(order)
      end

      it 'allows me to edit order details' do
        expect(page).to have_content('spree t-shirt')
        expect(page).to have_content('$40.00')

        within_row(1) do
          click_icon :edit
          fill_in 'quantity', with: '1'
        end
        click_icon :save

        within('#order_total') do
          expect(page).to have_content('$20.00')
        end
      end

      it 'can add an item to a shipment' do
        select2 'spree t-shirt', from: Spree.t(:name_or_sku), search: true

        within('table.stock-levels') do
          fill_in 'variant_quantity', with: 2
          click_icon :add
        end

        within('#order_total') do
          expect(page).to have_content('$80.00')
        end
      end

      it 'can remove an item from a shipment' do
        expect(page).to have_content('spree t-shirt')

        within_row(1) do
          accept_confirm do
            click_icon :delete
          end
        end

        # Click "ok" on confirmation dialog
        expect(page).not_to have_content('spree t-shirt')
      end

      # Regression test for #3862
      it 'can cancel removing an item from a shipment' do
        expect(page).to have_content('spree t-shirt')

        within_row(1) do
          # Click "cancel" on confirmation dialog
          dismiss_confirm do
            click_icon :delete
          end
        end

        expect(page).to have_content('spree t-shirt')
      end

      it 'can add tracking information' do
        visit spree.edit_admin_order_path(order)

        within('.show-tracking') do
          click_icon :edit
        end
        fill_in 'tracking', with: 'FOOBAR'
        click_icon :save

        expect(page).not_to have_css('input[name=tracking]')
        expect(page).to have_content('Tracking: FOOBAR')
      end

      it 'can change the shipping method' do
        order = create(:completed_order_with_totals)
        visit spree.edit_admin_order_path(order)
        within('table.table tr.show-method') do
          click_icon :edit
        end
        select2 'Default', from: 'Shipping Method'
        click_icon :save

        expect(page).not_to have_css('#selected_shipping_rate_id')
        expect(page).to have_content('Default')
      end

      it 'can assign a back-end only shipping method' do
        create(:shipping_method, name: 'Backdoor', display_on: 'back_end')
        order = create(
          :completed_order_with_totals,
          shipping_method_filter: Spree::ShippingMethod::DISPLAY_ON_BACK_END
        )
        visit spree.edit_admin_order_path(order)
        within('table tr.show-method') do
          click_icon :edit
        end
        select2 'Backdoor', from: 'Shipping Method'
        click_icon :save

        expect(page).not_to have_css('#selected_shipping_rate_id')
        expect(page).to have_content('Backdoor')
      end

      it 'will show the variant sku', js: false do
        order = create(:completed_order_with_totals)
        visit spree.edit_admin_order_path(order)
        sku = order.line_items.first.variant.sku
        expect(page).to have_content("SKU: #{sku}")
      end

      context 'with special_instructions present' do
        before do
          order.update_column(:special_instructions, 'Very special instructions here')
        end

        it 'will show the special_instructions', js: false do
          visit spree.edit_admin_order_path(order)
          expect(page).to have_content('Very special instructions here')
        end
      end

      context 'when not tracking inventory' do
        let(:tote) { create(:product, name: 'Tote', price: 15.00) }

        context "variant doesn't track inventory" do
          before do
            tote.master.update_column :track_inventory, false
            # make sure there's no stock level for any item
            tote.master.stock_items.update_all count_on_hand: 0, backorderable: false
          end

          it 'adds variant to order just fine' do
            select2 tote.name, from: Spree.t(:name_or_sku), search: true

            within('table.stock-levels') do
              fill_in 'variant_quantity', with: 1
              click_icon :add
            end

            within('.line-items') do
              expect(page).to have_content(tote.name)
            end
          end
        end

        context "site doesn't track inventory" do
          before do
            Spree::Config[:track_inventory_levels] = false
            tote.master.update_column(:track_inventory, true)
            # make sure there's no stock level for any item
            tote.master.stock_items.update_all count_on_hand: 0, backorderable: true
          end

          after { Spree::Config[:track_inventory_levels] = true }

          it 'adds variant to order just fine' do
            select2 tote.name, from: Spree.t(:name_or_sku), search: true
            within('table.stock-levels') do
              fill_in 'variant_quantity', with: 1
              click_icon :add
            end

            within('.line-items') do
              expect(page).to have_content(tote.name)
            end
          end
        end
      end

      context 'variant out of stock and not backorderable' do
        let(:tote) { create(:product, name: 'Tote', price: 15.00) }

        before do
          tote.master.stock_items.first.update(backorderable: false)
          tote.master.stock_items.first.update(count_on_hand: 0)
        end

        it 'does not add a product to the order' do
          select2 tote.name, from: Spree.t(:name_or_sku), search: true

          within('table.stock-levels') do
            expect(page).to have_content(Spree.t(:out_of_stock))
          end
        end
      end
    end

    context 'Shipment edit page' do
      let!(:stock_location2) { create(:stock_location_with_items, name: 'Clarksville') }

      before do
        product.master.stock_items.first.update_column(:backorderable, true)
        product.master.stock_items.first.update_column(:count_on_hand, 100)
        product.master.stock_items.last.update_column(:count_on_hand, 100)
      end

      context 'splitting to location' do
        before { visit spree.edit_admin_order_path(order) }

        it 'should warn you if you have not selected a location or shipment' do
          within_row(1) { click_icon :split }
          accept_alert "Please select the split destination" do
            click_icon :save
          end
        end

        context 'there is enough stock at the other location' do
          it 'allows me to make a split' do
            expect(order.shipments.count).to eq(1)
            expect(order.shipments.first.inventory_units_for(product.master).sum(&:quantity)).to eq(2)

            within_row(1) { click_icon 'split' }
            select2 stock_location2.name, css: '.stock-item-split', search: true, match: :first
            click_icon :save

            expect(page).to have_css('#order-form-wrapper div', id: /^shipment_\d$/).exactly(2).times

            order.reload

            expect(order.shipments.count).to eq(2)
            expect(order.shipments.last.backordered?).to eq(false)
            expect(order.shipments.first.inventory_units_for(product.master).sum(&:quantity)).to eq(1)
            expect(order.shipments.last.inventory_units_for(product.master).sum(&:quantity)).to eq(1)
          end

          it 'allows me to make a transfer via splitting off all stock' do
            expect(order.shipments.first.stock_location.id).to eq(stock_location.id)

            within_row(1) { click_icon 'split' }
            select2 stock_location2.name, css: '.stock-item-split', search: true, match: :first
            fill_in 'item_quantity', with: 2
            click_icon :save

            expect(page).not_to have_css('tr.stock-item-split')
            order.reload

            expect(order.shipments.count).to eq(1)
            expect(order.shipments.last.backordered?).to eq(false)
            expect(order.shipments.first.inventory_units_for(product.master).sum(&:quantity)).to eq(2)
            expect(order.shipments.first.stock_location.id).to eq(stock_location2.id)
          end

          it 'does not allow to split more than in the original shipment' do
            expect(order.shipments.first.stock_location.id).to eq(stock_location.id)

            within_row(1) { click_icon 'split' }
            select2 stock_location2.name, css: '.stock-item-split', search: true, match: :first
            fill_in 'item_quantity', with: 5
            click_icon :save

            expect(page).not_to have_css('tr.stock-item-split')
            order.reload

            expect(order.shipments.count).to eq(1)
            expect(order.shipments.last.backordered?).to eq(false)
            expect(order.shipments.first.inventory_units_for(product.master).sum(&:quantity)).to eq(2)
            expect(order.shipments.first.stock_location.id).to eq(stock_location2.id)
          end

          it 'does not split anything if the input quantity is garbage' do
            expect(order.shipments.first.stock_location.id).to eq(stock_location.id)

            within_row(1) { click_icon 'split' }
            select2 stock_location2.name, css: '.stock-item-split', search: true, match: :first
            fill_in 'item_quantity', with: 'ff'

            page.accept_confirm "quantity is negative" do
              click_icon :save
            end

            expect(order.shipments.count).to eq(1)
            expect(order.shipments.first.inventory_units_for(product.master).sum(&:quantity)).to eq(2)
            expect(order.shipments.first.stock_location.id).to eq(stock_location.id)
          end

          it 'does not allow less than or equal to zero qty' do
            expect(order.shipments.first.stock_location.id).to eq(stock_location.id)

            within_row(1) { click_icon 'split' }
            select2 stock_location2.name, css: '.stock-item-split', search: true, match: :first
            fill_in 'item_quantity', with: 0

            page.accept_confirm "quantity is negative" do
              click_icon :save
            end

            expect(order.shipments.count).to eq(1)
            expect(order.shipments.first.inventory_units_for(product.master).sum(&:quantity)).to eq(2)
            expect(order.shipments.first.stock_location.id).to eq(stock_location.id)

            fill_in 'item_quantity', with: -1

            page.accept_confirm "quantity is negative" do
              click_icon :save
            end

            expect(order.shipments.count).to eq(1)
            expect(order.shipments.first.inventory_units_for(product.master).sum(&:quantity)).to eq(2)
            expect(order.shipments.first.stock_location.id).to eq(stock_location.id)
          end

          context 'A shipment has shipped' do
            it 'does not show or let me back to the cart page, nor show the shipment edit buttons', js: false do
              order = create(:order, state: 'payment')
              order.shipments.create!(stock_location_id: stock_location.id, state: 'shipped')

              visit spree.cart_admin_order_path(order)

              expect(page).to have_current_path(spree.edit_admin_order_path(order))
              expect(page).not_to have_text 'Cart'
            end
          end
        end

        context 'there is not enough stock at the other location' do
          context 'and it cannot backorder' do
            it 'does not allow me to split stock' do
              product.master.stock_items.last.update_column(:backorderable, false)
              product.master.stock_items.last.update_column(:count_on_hand, 0)

              within_row(1) { click_icon 'split' }
              select2 stock_location2.name, css: '.stock-item-split', search: true, match: :first
              fill_in 'item_quantity', with: 2

              click_icon :save
              expect(page).not_to have_css('tr.stock-item-split')

              expect(order.shipments.count).to eq(1)
              expect(order.shipments.first.inventory_units_for(product.master).sum(&:quantity)).to eq(2)
              expect(order.shipments.first.stock_location.id).to eq(stock_location.id)
            end
          end

          context 'but it can backorder' do
            it 'allows me to split and backorder the stock' do
              product.master.stock_items.last.update_column(:count_on_hand, 0)
              product.master.stock_items.last.update_column(:backorderable, true)

              within_row(1) { click_icon 'split' }
              select2 stock_location2.name, css: '.stock-item-split', search: true, match: :first
              fill_in 'item_quantity', with: 2

              click_icon :save
              expect(page).not_to have_css('tr.stock-item-split')

              order.reload
              expect(order.shipments.count).to eq(1)
              expect(order.shipments.first.inventory_units_for(product.master).sum(&:quantity)).to eq(2)
              expect(order.shipments.first.stock_location.id).to eq(stock_location2.id)
            end
          end
        end

        context 'multiple items in cart' do
          it 'has no problem splitting if multiple items are in the from shipment' do
            Spree::Cart::AddItem.call(order: order, variant: create(:variant), quantity: 2)
            expect(order.shipments.count).to eq(1)
            expect(order.shipments.first.manifest.count).to eq(2)

            within_row(1) { click_icon 'split' }
            select2 stock_location2.name, css: '.stock-item-split', search: true, match: :first
            click_icon :save

            expect(page).to have_css('#order-form-wrapper div', id: /^shipment_\d$/).exactly(2).times

            order.reload
            expect(order.shipments.count).to eq(2)
            expect(order.shipments.last.backordered?).to eq(false)
            expect(order.shipments.first.inventory_units_for(product.master).sum(&:quantity)).to eq(1)
            expect(order.shipments.last.inventory_units_for(product.master).sum(&:quantity)).to eq(1)
          end
        end

        context 'when not tracking inventory' do
          let(:tote) { create(:product, name: 'Tote', price: 15.00) }

          context "variant doesn't track inventory" do
            before do
              tote.master.update_column :track_inventory, false
              # make sure there's no stock level for any item
              tote.master.stock_items.update_all count_on_hand: 0, backorderable: false
            end

            it 'adds variant to order just fine' do
              select2 tote.name, from: Spree.t(:name_or_sku), search: true
              within('table.stock-levels tbody tr', match: :first) do
                fill_in 'stock_item_quantity', match: :first, with: 1
                click_icon :add
              end

              expect(page).to have_css('[data-hook="add_product_name"]', text: 'Choose a variant')

              within('[data-hook=admin_order_form_fields]') do
                expect(page).to have_content(tote.name)
              end
            end
          end

          context "site doesn't track inventory" do
            before do
              Spree::Config[:track_inventory_levels] = false
              tote.master.update_column(:track_inventory, true)
              # make sure there's no stock level for any item
              tote.master.stock_items.update_all count_on_hand: 0, backorderable: true
            end

            after { Spree::Config[:track_inventory_levels] = true }

            it 'adds variant to order just fine' do
              select2 tote.name, from: Spree.t(:name_or_sku), search: true
              within('table.stock-levels') do
                fill_in 'stock_item_quantity', match: :first, with: 1
                click_icon :add
              end

              within('[data-hook=admin_order_form_fields]') do
                expect(page).to have_content(tote.name)
              end
            end
          end
        end

        context 'variant out of stock and not backorderable' do
          before do
            product.master.stock_items.first.update_column(:backorderable, false)
            product.master.stock_items.first.update_column(:count_on_hand, 0)
          end

          it 'displays out of stock instead of add button' do
            select2 product.name, from: Spree.t(:name_or_sku), search: true

            within('table.stock-levels') do
              expect(page).to have_content(Spree.t(:out_of_stock))
            end
          end
        end
      end

      context 'splitting to shipment' do
        before do
          @shipment2 = order.shipments.create(stock_location_id: stock_location2.id)
          visit spree.edit_admin_order_path(order)
        end

        it 'deletes the old shipment if enough are split off' do
          expect(order.shipments.count).to eq(2)

          within_row(1) { click_icon 'split' }
          select2 @shipment2.number, css: '.stock-item-split', search: true, match: :first
          fill_in 'item_quantity', with: 2

          click_icon :save

          expect(page).to have_css('#order-form-wrapper div', id: /^shipment_\d$/).once
          order.reload
          expect(order.shipments.count).to eq(1)
          expect(order.shipments.last.inventory_units_for(product.master).sum(&:quantity)).to eq(2)
        end

        context 'receiving shipment can not backorder' do
          before { product.master.stock_items.last.update_column(:backorderable, false) }

          it 'does not allow a split if the receiving shipment qty plus the incoming is greater than the count_on_hand' do
            expect(order.shipments.count).to eq(2)

            within_row(1) { click_icon 'split' }
            select2 @shipment2.number, css: '.stock-item-split', search: true, match: :first
            fill_in 'item_quantity', with: 1

            click_icon :save
            expect(page).not_to have_css('tr.stock-item-split')

            within_row(1) { click_icon 'split' }
            select2 @shipment2.number, css: '.stock-item-split', search: true, match: :first
            fill_in 'item_quantity', with: 200

            click_icon :save
            expect(page).not_to have_css('tr.stock-item-split')
            order.reload

            expect(order.shipments.count).to eq(2)
            expect(order.shipments.first.inventory_units_for(product.master).sum(&:quantity)).to eq(1)
            expect(order.shipments.last.inventory_units_for(product.master).sum(&:quantity)).to eq(1)
          end

          it 'does not allow a shipment to split stock to itself' do
            within_row(1) { click_icon 'split' }
            select2 order.shipments.first.number, css: '.stock-item-split', search: true, match: :first
            fill_in 'item_quantity', with: 1

            page.accept_confirm "target shipment is the same as original shipment" do
              click_icon :save
            end

            order.reload
            expect(order.shipments.count).to eq(2)
            expect(order.shipments.first.inventory_units_for(product.master).sum(&:quantity)).to eq(2)
          end

          it 'splits fine if more than one line_item is in the receiving shipment' do
            variant2 = create(:variant)
            Spree::Cart::AddItem.call(order: order, variant: variant2, quantity: 2, options: { shipment: @shipment2 })

            within_row(1) { click_icon 'split' }
            select2 @shipment2.number, css: '.stock-item-split', search: true, match: :first
            fill_in 'item_quantity', with: 1
            click_icon :save

            expect(page).to have_css("#shipment_#{@shipment2.id} tr.stock-item").twice

            expect(order.shipments.count).to eq(2)
            expect(order.shipments.first.inventory_units_for(product.master).sum(&:quantity)).to eq 1
            expect(order.shipments.last.inventory_units_for(product.master).sum(&:quantity)).to eq 1
            expect(order.shipments.first.inventory_units_for(variant2).sum(&:quantity)).to eq 0
            expect(order.shipments.last.inventory_units_for(variant2).sum(&:quantity)).to eq 2
          end
        end

        context 'receiving shipment can backorder' do
          it 'adds more to the backorder' do
            product.master.stock_items.last.update_column(:backorderable, true)
            product.master.stock_items.last.update_column(:count_on_hand, 0)
            expect(@shipment2.reload.backordered?).to eq(false)

            within_row(1) { click_icon 'split' }
            select2 @shipment2.number, css: '.stock-item-split', search: true, match: :first
            fill_in 'item_quantity', with: 1

            click_icon :save
            expect(page).not_to have_css('tr.stock-item-split')

            expect(@shipment2.reload.backordered?).to eq(true)

            within_row(1) { click_icon 'split' }
            select2 @shipment2.number, css: '.stock-item-split', search: true, match: :first
            fill_in 'item_quantity', with: 1
            click_icon :save

            expect(page).to have_css('#order-form-wrapper div', id: /^shipment_\d$/).once

            expect(order.shipments.count).to eq(1)
            expect(order.shipments.last.inventory_units_for(product.master).sum(&:quantity)).to eq(2)
            expect(@shipment2.reload.backordered?).to eq(true)
          end
        end
      end

      context 'display order summary' do
        before do
          visit spree.cart_admin_order_path(order)
        end

        it 'contains elements' do
          within('.additional-info') do
            expect(page).to have_content('complete')
            expect(page).to have_content('spree')
            expect(page).to have_content('backorder')
            expect(page).to have_content('balance due')
          end
        end
      end
    end
  end

  context 'with only read permissions' do
    before do
      allow_any_instance_of(Spree::Admin::BaseController).to receive(:spree_current_user).and_return(nil)
    end

    custom_authorization! do |_user|
      can [:admin, :index, :read, :edit], Spree::Order
    end

    it 'does not display forbidden links' do
      visit spree.edit_admin_order_path(order)

      expect(page).not_to have_button('cancel')
      expect(page).not_to have_button('Resend')

      # Order Tabs
      expect(page).not_to have_link('Details')
      expect(page).not_to have_link('Customer')
      expect(page).not_to have_link('Adjustments')
      expect(page).not_to have_link('Payments')
      expect(page).not_to have_link('Returns')

      # Order item actions
      expect(page).not_to have_css('.delete-item')
      expect(page).not_to have_css('.split-item')
      expect(page).not_to have_css('.edit-item')
      expect(page).not_to have_css('.edit-tracking')

      expect(page).not_to have_css('#add-line-item')
    end
  end

  context 'as Fakedispatch' do
    custom_authorization! do |_user|
      # allow dispatch to :admin, :index, and :edit on Spree::Order
      can [:admin, :edit, :index, :read], Spree::Order
      # allow dispatch to :index, :show, :create and :update shipments on the admin
      can [:admin, :manage, :read, :ship], Spree::Shipment
    end

    before do
      allow(Spree.user_class).to receive(:find_by).
        with(hash_including(:spree_api_key)).
        and_return(Spree.user_class.new)
    end

    it 'does not display order tabs or edit buttons without ability', js: false do
      visit spree.edit_admin_order_path(order)

      # Order Form
      expect(page).not_to have_css('.edit-item')
      # Order Tabs
      expect(page).not_to have_link('Details')
      expect(page).not_to have_link('Customer')
      expect(page).not_to have_link('Adjustments')
      expect(page).not_to have_link('Payments')
      expect(page).not_to have_link('Returns')
    end

    it 'can add tracking information' do
      visit spree.edit_admin_order_path(order)
      within('table.stock-contents tr:nth-child(5)', match: :first) do
        click_icon :edit
      end
      fill_in 'tracking', with: 'FOOBAR'
      click_icon :save

      expect(page).not_to have_css('input[name=tracking]')
      expect(page).to have_content('Tracking: FOOBAR')
    end

    it 'can change the shipping method' do
      order = create(:completed_order_with_totals)
      visit spree.edit_admin_order_path(order)
      within('table.table tr.show-method') do
        click_icon :edit
      end
      select2 'Default', from: 'Shipping Method'
      click_icon :save

      expect(page).not_to have_css('#selected_shipping_rate_id')
      expect(page).to have_content('Default')
    end

    it 'can ship' do
      order = create(:order_ready_to_ship)
      order.refresh_shipment_rates
      visit spree.edit_admin_order_path(order)
      click_on 'Ship'
      expect(page).to have_css('.shipment-state', text: 'shipped')
    end
  end
end
