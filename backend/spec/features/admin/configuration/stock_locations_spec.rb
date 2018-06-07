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
    visit current_path

    expect(find('#listing_stock_locations')).to have_content(stock_location.name)
    spree_accept_alert do
      click_icon :delete
      # Wait for API request to complete.
      wait_for_ajax
    end
    visit current_path
    expect(page).to have_content('No Stock Locations found')
  end

  it 'can update an existing stock location', js: true do
    visit current_path

    expect(page).to have_content(stock_location.name)

    click_icon :edit
    fill_in 'Name', with: 'London'
    click_button 'Update'

    expect(page).to have_content('successfully updated')
    expect(page).to have_content('London')
  end
end
