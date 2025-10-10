require 'spec_helper'

describe 'Option Types', type: :feature do
  stub_authorization!
  describe 'listing option types' do
    before do
      Spree::OptionType.find_or_create_by(presentation: 'Color')
      Spree::OptionType.find_or_create_by(presentation: 'Size')
    end

    it 'lists existing option types' do
      visit spree.admin_option_types_path
      within('#listing_option_types') do
        expect(page).to have_content('Color')
        expect(page).to have_content('color')
        expect(page).to have_content('Size')
        expect(page).to have_content('size')
      end
    end
  end

  describe 'creating and updating a new option type' do
    it 'allows an admin to create a new option type' do
      visit spree.new_admin_option_type_path
      fill_in 'Presentation', with: 'Hat Size'
      click_button 'Create'
      expect(page).to have_content('successfully created!')

      fill_in 'Presentation', with: 'Hat Size Updated'
      within('#page-header') { click_button 'Update' }
      expect(page).to have_content('successfully updated!')
    end
  end

  describe 'manaing option values', js: true do
    let(:option_type) { create(:option_type) }

    it 'allows an admin to manage option values' do
      visit spree.edit_admin_option_type_path(option_type)

      within('#option_values') do
        within_row(1) do
          find('td.presentation').find('input:first-child').set('Small')
        end

        click_button 'add_option_value_button'

        within_row(2) do
          find('td.presentation').find('input:first-child').set('Large')
        end
      end

      within('#page-header') { click_button 'Update' }
      expect(page).to have_content('successfully updated!')

      expect(option_type.option_values.pluck(:presentation)).to include('Small', 'Large')
      expect(option_type.option_values.pluck(:name)).to include('small', 'large')

      within('#option_values') do
        within_row(2) do
          find('.remove_option_value_button').click
        end
      end

      within('#page-header') { click_button 'Update' }
      expect(page).to have_content('successfully updated!')

      expect(option_type.option_values.pluck(:presentation)).to include('Small')
      expect(option_type.option_values.pluck(:name)).to include('small')
    end
  end
end
