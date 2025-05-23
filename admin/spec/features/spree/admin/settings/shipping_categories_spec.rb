require 'spec_helper'

RSpec.feature 'Shipping categories' do
  stub_authorization!

  it 'can create new shipping category' do
    visit spree.admin_shipping_categories_path
    click_on 'New Shipping Category'

    fill_in 'Name', with: 'New Shipping Category'

    click_on 'Create'

    wait_for_turbo
    expect(page).to have_content 'Shipping Category "New Shipping Category" has been successfully created!'

    expect(Spree::ShippingCategory.count).to eq 1

    shipping_category = Spree::ShippingCategory.first

    expect(shipping_category.name).to eq 'New Shipping Category'
  end

  it 'can edit shipping category' do
    shipping_category = create(:shipping_category, name: 'Standard')

    visit spree.admin_shipping_categories_path
    click_on 'Edit'

    fill_in 'Name', with: 'Express'

    within('#page-header') { click_button 'Update' }

    wait_for_turbo
    expect(page).to have_content 'Shipping Category "Express" has been successfully updated!'

    shipping_category.reload
    expect(shipping_category.name).to eq 'Express'
  end

  it 'can delete shipping category', js: true do
    shipping_category = create(:shipping_category, name: 'Standard')

    visit spree.admin_shipping_categories_path
    click_on 'Edit'
    wait_for_turbo

    accept_confirm do
      click_on 'Delete'
    end

    wait_for_turbo
    expect(page).to have_content "Shipping Category \"#{shipping_category.name}\" has been successfully removed!"

    expect(Spree::ShippingCategory.count).to eq 0
  end

  it 'should list shipping categories' do
    create(:shipping_category, name: 'Standard')
    create(:shipping_category, name: 'Express')

    visit spree.admin_shipping_categories_path

    expect(page).to have_content 'Standard'
    expect(page).to have_content 'Express'
  end
end
