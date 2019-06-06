shared_context 'checkout setup' do
  let!(:country) { create(:country, states_required: true) }
  let!(:state) { create(:state, country: country) }
  let!(:shipping_method) { create(:shipping_method) }
  let!(:stock_location) { create(:stock_location) }
  let!(:mug) { create(:product, name: 'RoR Mug') }
  let!(:payment_method) { create(:check_payment_method) }
  let!(:zone) { create(:zone) }
  let!(:store) { create(:store) }
end

shared_context 'proceed to payment step' do
  before do
    add_to_cart('RoR Mug')
    click_button 'Checkout'
    fill_in 'order_email', with: 'spree@example.com'
    fill_in 'First Name', with: 'John'
    fill_in 'Last Name', with: 'Smith'
    fill_in 'Address', with: '1 John Street'
    fill_in 'City', with: 'City of John'
    fill_in 'Zip', with: '01337'
    select country.name, from: 'Country'
    select state.name, from: 'order[bill_address_attributes][state_id]'
    fill_in 'Phone', with: '555-555-5555'

    # To shipping method screen
    click_button 'Save and Continue'
    # To payment screen
    click_button 'Save and Continue'
  end
end
