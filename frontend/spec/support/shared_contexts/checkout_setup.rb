shared_context 'checkout setup' do
  let!(:country) { create(:country, states_required: true) }
  let!(:state) { create(:state, country: country) }
  let!(:shipping_method) { create(:shipping_method) }
  let!(:stock_location) { create(:stock_location) }
  let!(:mug) { create(:product, name: 'RoR Mug') }
  let!(:credit_card_payment) { create(:credit_card_payment_method, stores: [store]) }
  let!(:check_payment) { create(:check_payment_method, stores: [store]) }
  let!(:unsupported_payment) { create(:check_payment_method, stores: [create(:store)]) }
  let!(:zone) { create(:zone) }
  let!(:store) { create(:store) }

  def fill_in_address
    address = 'order_bill_address_attributes'
    fill_in "#{address}_firstname", with: 'Ryan'
    fill_in "#{address}_lastname", with: 'Bigg'
    fill_in "#{address}_address1", with: '143 Swan Street'
    fill_in "#{address}_city", with: 'Richmond'
    select country.name, from: "#{address}_country_id"
    select state.name, from: "#{address}_state_id"
    fill_in "#{address}_zipcode", with: '12345'
    fill_in "#{address}_phone", with: '(555) 555-5555'
  end

  def fill_in_credit_card_info(invalid: false)
    fill_in 'name_on_card', with: 'Spree Commerce'
    fill_in 'card_number', with: invalid ? '123' : '4111 1111 1111 1111'
    fill_in 'card_expiry', with: '12 / 24'
    fill_in 'card_code', with: '123'
  end

  def add_mug_to_cart
    add_to_cart(mug)
  end
end

shared_context 'proceed to payment step' do
  before do
    add_to_cart(mug) do
      click_link 'Checkout'
    end
    fill_in 'order_email', with: 'spree@example.com'
    fill_in 'First Name *', with: 'John'
    fill_in 'Last Name *', with: 'Smith'
    fill_in 'Address *', with: '1 John Street'
    fill_in 'City *', with: 'City of John'
    fill_in 'Zip Code *', with: '01337'
    select country.name, from: 'order[bill_address_attributes][country_id]'
    select state.name, from: 'order[bill_address_attributes][state_id]'
    fill_in 'Phone *', with: '555-555-5555'

    # To shipping method screen
    click_button 'Save and Continue'
    # To payment screen
    click_button 'Save and Continue'
  end
end
