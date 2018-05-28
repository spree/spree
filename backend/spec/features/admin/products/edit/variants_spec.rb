require 'spec_helper'

describe 'Product Variants', type: :feature, js: true do
  stub_authorization!

  before do
    create(:product)
    visit spree.admin_products_path
  end

  context 'editing variant option types' do
    it 'allows an admin to create option types for a variant' do
      within_row(1) { click_icon :edit }

      within('#sidebar') { click_link 'Variants' }
      expect(page).to have_content('To add variants, you must first define')
    end

    it 'allows admin to create a variant if there are option types' do
      click_link 'Option Types'
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

      select2_search 'shirt', from: 'Option Types'
      click_button 'Update'
      expect(page).to have_content('successfully updated!')

      within('#sidebar') { click_link 'Variants' }
      click_link 'New Variant'

      targetted_select2 'black', from: '#s2id_variant_option_value_ids'
      fill_in 'variant_sku', with: 'A100'
      click_button 'Create'
      expect(page).to have_content('successfully created!')

      within('.table') do
        expect(page).to have_content('19.99')
        expect(page).to have_content('black')
        expect(page).to have_content('A100')
      end
    end
  end
end
