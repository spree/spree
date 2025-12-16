require 'spec_helper'

RSpec.feature 'Shipping methods', js: true do
  before do
    Spree::Seeds::Countries.call
    Spree::Seeds::Zones.call
    Spree::Seeds::ShippingCategories.call
  end

  stub_authorization!

  it 'allows Store Owner to create new shipping method' do
    visit spree.new_admin_shipping_method_path

    fill_in 'Name', with: 'New Shipping Method', match: :first
    select 'Flat rate', from: 'Calculator'

    expect(page).to have_content 'Flat rate'
    fill_in 'Amount', with: '10'

    fill_in 'Min', with: '2' # Minimum estimated delivery time
    fill_in 'Max', with: '5' # Maximum estimated delivery time

    uncheck 'Middle East', allow_label_click: true
    check 'Digital', allow_label_click: true

    click_on 'Create'

    expect(page).to have_content 'has been successfully created!'

    expect(Spree::ShippingMethod.count).to eq 1

    shipping_method = Spree::ShippingMethod.first

    expect(shipping_method.name).to eq 'New Shipping Method'
    expect(shipping_method.calculator.class).to eq Spree::Calculator::Shipping::FlatRate
    expect(shipping_method.calculator.preferred_amount).to eq 10
    expect(shipping_method.zones.pluck(:name)).not_to include 'Middle East'
    expect(shipping_method.shipping_categories.pluck(:name)).to include 'Digital'
    expect(shipping_method.estimated_transit_business_days_min).to eq 2
    expect(shipping_method.estimated_transit_business_days_max).to eq 5
  end

  it 'allows Store Owner to edit shipping method' do
    shipping_method = create(:shipping_method, name: 'Standard', display_on: 'both')

    visit spree.edit_admin_shipping_method_path(shipping_method)

    fill_in 'Name', with: 'Express', match: :first
    select 'Flat Percent', from: 'Calculator'

    expect(page).to have_content 'Flat Percent'
    fill_in 'Flat Percent', with: '5'

    fill_in 'Min', with: '3'
    fill_in 'Max', with: '6'

    uncheck 'Middle East', allow_label_click: true
    check 'Digital', allow_label_click: true

    within('#page-header') { click_button 'Update' }

    wait_for_turbo
    expect(page).to have_content 'has been successfully updated!'

    shipping_method.reload

    expect(shipping_method.name).to eq 'Express'
    expect(shipping_method.calculator.class).to eq Spree::Calculator::Shipping::FlatPercentItemTotal
    expect(shipping_method.calculator.preferred_flat_percent).to eq 5
    expect(shipping_method.zones.pluck(:name)).not_to include 'Middle East'
    expect(shipping_method.shipping_categories.pluck(:name)).to include 'Digital'
    expect(shipping_method.estimated_transit_business_days_min).to eq 3
    expect(shipping_method.estimated_transit_business_days_max).to eq 6
  end

  it 'allows Store Owner to delete shipping method' do
    shipping_method = create(:shipping_method)

    visit spree.edit_admin_shipping_method_path(shipping_method)

    accept_confirm do
      click_on 'Delete'
    end

    expect(page).to have_content "has been successfully removed!"

    expect(Spree::ShippingMethod.count).to eq 0
  end
end
