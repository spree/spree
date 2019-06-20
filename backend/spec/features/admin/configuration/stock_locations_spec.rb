require 'spec_helper'

describe 'Stock Locations', type: :feature do
  stub_authorization!
  let!(:stock_location) { create(:stock_location) }

  before do
    visit spree.admin_stock_locations_path
  end

  it 'can create a new stock location' do
    click_link 'New Stock Location'
    fill_in 'Name', with: 'London'
    check 'Active'
    click_button 'Create'

    expect(page).to have_content('successfully created')
    expect(page).to have_content('London')
  end

  it 'can delete an existing stock location', js: true do
    refresh
    expect(page).to have_css('#listing_stock_locations', text: stock_location.name)
    accept_confirm do
      click_icon :delete
    end
    expect(page).not_to have_css('#listing_stock_locations tbody tr')
    refresh
    wait_for { !page.has_text?('No Stock Locations found') }
    expect(page).to have_content('No Stock Locations found')
  end

  it 'can update an existing stock location', js: true do
    refresh

    expect(page).to have_content(stock_location.name)

    click_icon :edit
    fill_in 'Name', with: 'London'
    click_button 'Update'

    expect(page).to have_content('successfully updated')
    expect(page).to have_content('London')
  end
end
