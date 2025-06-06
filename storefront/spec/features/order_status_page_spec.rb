require 'spec_helper'

describe 'Order Status Page', type: :feature do
  let!(:order) { create(:order_ready_to_ship, number: 'R1234567', email: 'jon@snow.org', user: nil, store: Spree::Store.default, ship_address: create(:address), bill_address: create(:bill_address)) }

  context 'when order is not found' do
    it 'shows error message' do
      visit spree.new_order_status_path
      fill_in 'email', with: 'jon@snow.org'
      fill_in 'number', with: 'R1234568'
      click_button 'Find your order'
      expect(page).to have_content("We couldn't find your order")
    end
  end

  context 'when order is found' do
    it 'shows order details' do
      visit spree.new_order_status_path
      fill_in 'email', with: order.email
      fill_in 'number', with: order.number
      click_button 'Find your order'
      expect(page).to have_content('Order R1234567')
      expect(page).to have_current_path(spree.order_path(order, token: order.token))
    end
  end
end
