require 'spec_helper'

describe 'Option Types', type: :feature, js: true do
  stub_authorization!

  before do
    visit spree.admin_path
    click_link 'Products'
  end

  context 'listing option types' do
    it 'lists existing option types' do
      create(:option_type, name: 'tshirt-color', presentation: 'Color')
      create(:option_type, name: 'tshirt-size', presentation: 'Size')
      click_link 'Option Types'
      within('table#listing_option_types') do
        expect(page).to have_content('Color')
        expect(page).to have_content('tshirt-color')
        expect(page).to have_content('Size')
        expect(page).to have_content('tshirt-size')
      end
    end
  end

  context 'creating a new option type' do
    it 'allows an admin to create a new option type' do
      click_link 'Option Types'
      click_link 'new_option_type_link'
      expect(page).to have_content('New Option Type')
      fill_in 'option_type_name', with: 'shirt colors'
      fill_in 'option_type_presentation', with: 'colors'
      click_button 'Create'
      expect(page).to have_content('successfully created!')

      page.find('#option_type_option_values_attributes_0_name').set('color')
      page.find('#option_type_option_values_attributes_0_presentation').set('black')

      click_button 'Update'
      expect(page).to have_content('successfully updated!')
    end
  end

  context 'editing an existing option type' do
    it 'allows an admin to update an existing option type' do
      create(:option_type, name: 'tshirt-color', presentation: 'Color')
      create(:option_type, name: 'tshirt-size', presentation: 'Size')
      click_link 'Option Types'
      within('table#listing_option_types') { click_icon :edit }
      fill_in 'option_type_name', with: 'foo-size 99'
      click_button 'Update'
      expect(page).to have_content('successfully updated!')
      expect(page).to have_content('foo-size 99')
    end
  end

  # Regression test for #3204
  it 'can remove a non-persisted option value from an option type' do
    create(:option_type)
    click_link 'Option Types'
    within('table#listing_option_types') { click_icon :edit }

    expect(page).to have_css('tbody#sortVert tr', count: 1)

    # Add a new option type
    click_link 'Add Option Value'
    expect(page).to have_css('tbody#sortVert tr', count: 2)

    # Remove default option type
    within('tbody#sortVert') do
      click_icon :delete
    end
    # Check that there was no HTTP request
    expect(page).not_to have_css('div#progress[style]')
    # Assert that the field is hidden automatically
    expect(page).to have_css('tbody#sortVert tr', count: 1)

    # Remove added option type
    within('tbody#sortVert') do
      click_icon :delete
    end
    # Check that there was no HTTP request
    expect(page).not_to have_css('div#progress[style]')
    # Assert that the field is hidden automatically
    expect(page).not_to have_css('tbody#option_values tr')
  end
end
