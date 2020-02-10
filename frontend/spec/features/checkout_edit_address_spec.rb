require 'spec_helper'

describe 'User editing saved address during checkout', type: :feature, js: true do
  include_context 'checkout address book'
  include_context 'user with address'

  before { click_link 'checkout' }

  it 'can update billing address' do
    within("#billing #billing_address_#{address.id}") do
      find("a[href='#{spree.edit_address_path(address)}']").click
    end
    expect(page).to have_current_path spree.edit_address_path(address)
    new_street = FFaker::Address.street_address
    fill_in "#{I18n.t('activerecord.attributes.spree/address.address1')} #{Spree.t(:required)}", with: new_street
    click_button 'Update'
    user.reload
    refresh
    expect(page).to have_current_path spree.checkout_state_path('address')
    within('h1') { expect(page).to have_content('CHECKOUT') }
    within('#billing') do
      expect(page).to have_content(new_street)
    end
  end

  it 'can update shipping address' do
    find('label', text: 'Use Billing Address').click
    within("#shipping #shipping_address_#{address.id}") do
      find("a[href='#{spree.edit_address_path(address)}']").click
    end
    expect(page).to have_current_path spree.edit_address_path(address)
    new_street = FFaker::Address.street_address
    fill_in "#{I18n.t('activerecord.attributes.spree/address.address1')} #{Spree.t(:required)}", with: new_street
    click_button 'Update'
    user.reload
    refresh
    expect(page).to have_current_path spree.checkout_state_path('address')
    within('h1') { expect(page).to have_content('CHECKOUT') }
    find('label', text: 'Use Billing Address').click
    within('#shipping') do
      expect(page).to have_content(new_street)
    end
  end
end
