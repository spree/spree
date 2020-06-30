require 'spec_helper'

describe 'Product Variants', type: :feature, js: true do
  stub_authorization!

  before do
    create(:product)
    create(:store, default: true, default_currency: 'USD')
    visit spree.admin_products_path
  end

  context 'editing variant option types' do
    it 'allows an admin to create option types for a variant' do
      within_row(1) { click_icon :edit }

      within('#sidebar') { click_link 'Variants' }
      expect(page).to have_content('To add variants, you must first define')
    end

    it 'allows admin to create a variant if there are option types' do
      within_row(1) { click_icon :edit }

      within('#sidebar') { click_link 'Variants' }
      click_link 'Option Values'
      click_link 'new_option_type_link'
      fill_in 'option_type_name', with: 'shirt colors'
      fill_in 'option_type_presentation', with: 'colors'
      click_button 'Create'
      expect(page).to have_content('successfully created!')

      page.find('#option_type_option_values_attributes_0_name').set('color')
      page.find('#option_type_option_values_attributes_0_presentation').set('black')
      click_button 'Update'
      expect(page).to have_content('successfully updated!')

      visit spree.admin_products_path
      within_row(1) { click_icon :edit }

      select2 'shirt', from: 'Option Types'
      wait_for { !page.has_button?('Update') }
      click_button 'Update'
      expect(page).to have_content('successfully updated!')

      within('#sidebar') { click_link 'Variants' }
      click_link 'New Variant'

      select2 'black', from: 'Colors'
      fill_in 'variant_sku', with: 'A100'
      click_button 'Create'
      expect(page).to have_content('successfully created!')

      within('.table') do
        expect(page).to have_content('19.99')
        expect(page).to have_content('black')
        expect(page).to have_content('A100')
      end
    end

    it 'allows admin to edit a variants compare at price' do
      within_row(1) { click_icon :edit }

      within('#sidebar') { click_link 'Variants' }
      click_link 'Option Values'
      click_link 'new_option_type_link'
      fill_in 'option_type_name', with: 'shirt colors'
      fill_in 'option_type_presentation', with: 'colors'
      click_button 'Create'

      page.find('#option_type_option_values_attributes_0_name').set('color')
      page.find('#option_type_option_values_attributes_0_presentation').set('black')
      click_button 'Update'

      visit spree.admin_products_path
      within_row(1) { click_icon :edit }

      select2 'shirt', from: 'Option Types'
      wait_for { !page.has_button?('Update') }
      click_button 'Update'

      within('#sidebar') { click_link 'Variants' }
      click_link 'New Variant'

      select2 'black', from: 'Colors'
      fill_in 'variant_sku', with: 'A100'
      click_button 'Create'

      within_row(1) { click_icon :edit }
      fill_in 'variant_compare_at_price', with: '99.99'
      click_button 'Update'

      expect(page).to have_content('successfully updated!')
    end
  end
end
