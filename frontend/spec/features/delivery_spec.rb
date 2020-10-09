require 'spec_helper'

describe 'Delivery', type: :feature, inaccessible: true, js: true do
  include_context 'checkout setup'

  let(:country) { create(:country, name: 'United States of America', iso_name: 'UNITED STATES', iso: 'US') }
  let(:state) { create(:state, name: 'Alabama', abbr: 'AL', country: country) }
  let(:user) { create(:user) }
  let!(:shipping_method2) do
    sm = create(:shipping_method, name: 'Shipping Method2')
    sm.calculator.preferred_amount = 20
    sm.calculator.save
    sm
  end

  def add_mug_and_navigate_to_delivery_page
    add_to_cart(mug) do
      click_link 'Checkout'
    end

    fill_in 'order_email', with: 'test@example.com'
    fill_in_address

    click_button 'Save and Continue'
  end

  before do
    create(:product) # product 2
    shipping_method.calculator.preferred_amount = 10
    shipping_method.calculator.save
  end

  describe 'shipping total gets updated when shipping method is changed in the delivery step' do
    before do
      add_mug_and_navigate_to_delivery_page
    end

    it 'contains the shipping total' do
      expect(page).to have_css(".checkout-content-summary-table", text: '$10.00')
    end

    context 'shipping method is changed' do
      before { find('label', text: shipping_method2.name).click }
        it 'shipping total and order total both are updates' do
          expect(page).to have_css(".checkout-content-summary-table", text: '$20.00')
        end
    end
  end

  describe 'shipping address is displayed on delivery page' do
    before do
      add_mug_and_navigate_to_delivery_page
    end

    it 'contains the correct address' do
      expect(page).to have_text 'SHIPPING TO: ' + @street.upcase + ' - ' + @zipcode.upcase + ' - US'
    end
  end

  context 'custom currency markers' do
    before do
      Spree::Money.default_formatting_rules[:decimal_mark] = ','
      Spree::Money.default_formatting_rules[:thousands_separator] = '.'

      add_mug_and_navigate_to_delivery_page

      find('label', text: shipping_method2.name).click
    end

    after do
      Spree::Money.default_formatting_rules.delete(:decimal_mark)
      Spree::Money.default_formatting_rules.delete(:thousands_separator)
    end

    it 'calculates shipping total correctly with different currency marker' do
      expect(page).to have_css(".checkout-content-summary-table", text: '$20,00')
    end

    it 'calculates order total correctly with different currency marker' do
      expect(page).to have_css(".checkout-content-summary-table", text: '$39,99')
    end
  end

  def fill_in_address
    @street = FFaker::Address.street_address
    @zipcode = FFaker::AddressUS.zip_code
    address = 'order_bill_address_attributes'
    fill_in "#{address}_firstname", with: FFaker::Name.first_name
    fill_in "#{address}_lastname", with: FFaker::Name.last_name
    fill_in "#{address}_address1", with: @street
    fill_in "#{address}_city", with: FFaker::Address.city
    select country.name, from: "#{address}_country_id"
    select state.name, from: "#{address}_state_id"
    fill_in "#{address}_zipcode", with: @zipcode
    fill_in "#{address}_phone", with: FFaker::PhoneNumber.phone_number
  end
end
