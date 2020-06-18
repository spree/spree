require 'spec_helper'

describe 'Product Properties', type: :feature, js: true do
  stub_authorization!

  before do
    create(:product)
    visit spree.admin_products_path
  end

  context 'editing product properties' do
    it 'allows admin to create a new property' do
      within_row(1) { click_icon :edit }

      within('#sidebar') { click_link 'Properties' }
      fill_in 'product_product_properties_attributes_0_property_name', with: 'Material'
      fill_in 'product_product_properties_attributes_0_value', with: 'Leather'
      click_button 'Update'

      within('#sidebar') { click_link 'Properties' }
      expect(page).to have_content('Add Product Properties')
      expect(page).to have_content('SHOW PROPERTY')
      expect(page).to have_selector("input[value='Material']")
      expect(page).to have_selector("input[value='Leather']")
      expect(page).to have_field('product_product_properties_attributes_0_show_property', checked: true)
    end

    it 'allows admin to create a new property and not show the property on the storefront' do
      within_row(1) { click_icon :edit }

      within('#sidebar') { click_link 'Properties' }
      fill_in 'product_product_properties_attributes_0_property_name', with: 'gtin'
      fill_in 'product_product_properties_attributes_0_value', with: '9020188287332'
      find(:css, "#product_product_properties_attributes_0_show_property").set(false)
      click_button 'Update'

      within('#sidebar') { click_link 'Properties' }
      expect(page).to have_selector("input[value='gtin']")
      expect(page).to have_selector("input[value='9020188287332']")
      expect(page).to have_field('product_product_properties_attributes_0_show_property', checked: false)
    end
  end
end
