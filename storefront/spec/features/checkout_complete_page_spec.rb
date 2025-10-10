require 'spec_helper'
RSpec.describe 'Checkout complete page', js: true do
  let(:store) { Spree::Store.default }
  let(:order) { create(:completed_order_with_pending_payment, user: nil, store: store) }
  let(:address) { order.bill_address }

  scenario 'Customer sees a confirmation page' do
    visit "/checkout/#{order.token}/complete"

    expect(page).to have_text("Order #{order.number}")
    expect(page).to have_text("Thanks #{address.first_name} for your order!")
  end
end
