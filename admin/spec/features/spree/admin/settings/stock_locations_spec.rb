require 'spec_helper'

RSpec.feature 'Stock Locations', js: true do
  let!(:stock_location) { create(:stock_location) }

  stub_authorization!

  it 'renders a list of stock locations' do
    visit spree.admin_stock_locations_path
    expect(page).to have_content(stock_location.name)
  end

  it 'allows to create a new stock location' do
    visit spree.new_admin_stock_location_path
    fill_in 'stock_location_name', with: 'New Stock Location'
    fill_in 'Internal Name', with: 'New Stock Location Internal Name'

    fill_in 'Address', with: 'New Stock Location Street Address'
    fill_in 'Address (contd.)', with: 'New Stock Location Street Address (contd)'
    fill_in 'City', with: 'New Stock Location City'
    fill_in 'Zip Code', with: 'New Stock Location Zip Code'
    fill_in 'Phone', with: 'New Stock Location Phone'

    click_button 'Create'
    expect(page).to have_content('Location "New Stock Location" has been successfully created!')

    stock_location = Spree::StockLocation.last
    expect(stock_location.address1).to eq('New Stock Location Street Address')
    expect(stock_location.address2).to eq('New Stock Location Street Address (contd)')
    expect(stock_location.city).to eq('New Stock Location City')
    expect(stock_location.zipcode).to eq('New Stock Location Zip Code')
    expect(stock_location.phone).to eq('New Stock Location Phone')
    expect(stock_location.country).to eq(Spree::Country.find_by(iso: 'US'))
  end

  it 'allows to update an existing stock location' do
    visit spree.edit_admin_stock_location_path(stock_location)
    fill_in 'stock_location_name', with: ''
    fill_in 'stock_location_name', with: 'Updated Stock Location'
    within('#page-header') { click_button 'Update' }
    expect(page).to have_content("Location \"Updated Stock Location\" has been successfully updated")
  end

  it 'allows to delete a stock location' do
    visit spree.edit_admin_stock_location_path(stock_location)
    accept_confirm do
      click_on 'Delete'
    end
    expect(page).to have_content("Location \"#{stock_location.name}\" has been successfully removed!")
  end
end
