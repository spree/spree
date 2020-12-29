require 'spec_helper'

describe 'New Order', type: :feature do
  let!(:product) { create(:product_in_stock) }
  let!(:state) { create(:state) }
  let!(:user) { create(:user, ship_address: create(:address), bill_address: create(:address)) }

  stub_authorization!

  before do
    create(:check_payment_method)
    create(:shipping_method)
    # create default store
    allow(Spree.user_class).to receive(:find_by).and_return(user)
    create(:store)
    visit spree.new_admin_order_path
  end

  it 'does check if you have a billing address before letting you add shipments' do
    click_on 'Shipments'
    expect(page).to have_content 'Please fill in customer info'
    expect(page).to have_current_path(spree.edit_admin_order_customer_path(Spree::Order.last))
  end

  it 'completes new order successfully without using the cart', js: true do
    select2 product.name, from: Spree.t(:name_or_sku), search: true

    click_icon :add
    expect(page).to have_css('.card', text: 'Order Line Items')

    click_on 'Customer'
    select_customer

    check 'order_use_billing'
    fill_in_address
    click_on 'Update'

    click_on 'Payments'
    click_on 'Update'

    expect(page).to have_current_path(spree.admin_order_payments_path(Spree::Order.last))
    click_icon 'capture'

    click_on 'Shipments'
    click_on 'Ship'

    expect(page).to have_content('shipped')
  end

  context 'adding new item to the order', js: true do
    it 'inventory items show up just fine and are also registered as shipments' do
      select2 product.name, from: Spree.t(:name_or_sku), search: true

      within('table.stock-levels') do
        fill_in 'variant_quantity', with: 2
        click_icon :add
      end

      within('.line-items') do
        expect(page).to have_content(product.name)
      end

      click_on 'Customer'
      select_customer

      check 'order_use_billing'
      fill_in_address
      click_on 'Update'

      click_on 'Shipments'

      within('.stock-contents') do
        expect(page).to have_content(product.name)
      end
    end
  end

  context "adding new item to the order which isn't available", js: true do
    before do
      product.update(available_on: nil)
      select2 product.name, from: Spree.t(:name_or_sku), search: true
    end

    it 'inventory items is displayed' do
      expect(page).to have_content(product.name)
      expect(page).to have_css('#stock_details')
    end

    context 'on increase in quantity the product should be removed from order' do
      before do
        accept_alert do
          within('table.stock-levels') do
            fill_in 'variant_quantity', with: 2
            click_icon :add
          end
        end
      end

      it { expect(page).not_to have_css('#stock_details') }
    end
  end

  # Regression test for #3958
  context 'without a delivery step', js: true do
    before do
      allow(Spree::Order).to receive_messages checkout_step_names: [:address, :payment, :confirm, :complete]
    end

    it 'can still see line items' do
      select2 product.name, from: Spree.t(:name_or_sku), search: true
      click_icon :add
      within('.line-items') do
        within('.line-item-name') do
          expect(page).to have_content(product.name)
        end
        within('.line-item-qty-show') do
          expect(page).to have_content('1')
        end
        within('.line-item-price') do
          expect(page).to have_content(product.price)
        end
      end
    end
  end

  # Regression test for #3336
  context 'start by customer address' do
    it 'completes order fine', js: true do
      click_on 'Customer'
      select_customer

      check 'order_use_billing'
      fill_in_address
      click_on 'Update'

      click_on 'Shipments'
      select2 product.name, from: Spree.t(:name_or_sku), search: true
      click_icon :add
      expect(page).not_to have_content('Your order is empty')

      click_on 'Payments'
      click_on 'Continue'

      expect(page).to have_css('.additional-info .state', text: 'complete')
    end
  end

  # Regression test for #5327
  context 'customer with default credit card', js: true do
    before do
      allow(Spree.user_class).to receive(:find_by).and_return(user)
      create(:credit_card, default: true, user: user)
    end

    it 'transitions to delivery not to complete' do
      select2 product.name, from: Spree.t(:name_or_sku), search: true

      within('table.stock-levels') do
        fill_in 'variant_quantity', with: 1
        click_icon :add
      end
      expect(page).not_to have_content('Your order is empty')

      click_link 'Customer'
      select_customer
      wait_for { !page.has_button?('Update') }
      click_button 'Update'
      expect(Spree::Order.last.state).to eq 'delivery'
    end
  end

  def fill_in_address(kind = 'bill')
    fill_in 'First Name',                with: 'John 99'
    fill_in 'Last Name',                 with: 'Doe'
    fill_in 'Address',                   with: '100 first lane'
    fill_in 'Address (contd.)',          with: '#101'
    fill_in 'City',                      with: 'Bethesda'
    fill_in 'Zip Code',                  with: '20170'
    select2 state.name,                   css: '#bstate'
    fill_in 'Phone',                     with: '123-456-7890'
  end

  def select_customer
    within 'div#select-customer' do
      select2 user.email, css: '#customer-search-field', search: true
    end
  end
end
