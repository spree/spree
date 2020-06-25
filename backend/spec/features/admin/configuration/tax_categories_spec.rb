require 'spec_helper'

describe 'Tax Categories', type: :feature do
  stub_authorization!

  before do
    visit spree.admin_path
    click_link 'Configuration'
  end

  context 'admin visiting tax categories list' do
    it 'displays the existing tax categories' do
      create(:tax_category, name: 'Clothing', tax_code: 'CL001', description: 'For Clothing')
      click_link 'Tax Categories'
      within('h1') { expect(page).to have_content('Tax Categories') }
      within_row(1) do
        expect(column_text(1)).to eq('Clothing')
        expect(column_text(2)).to eq('CL001')
        expect(column_text(3)).to eq('For Clothing')
        expect(column_text(4)).to eq('No')
      end
    end
  end

  context 'admin creating new tax category' do
    before do
      click_link 'Tax Categories'
      within find('#contentHeader') do
        click_link 'admin_new_tax_categories_link'
      end
    end

    it 'is able to create new tax category' do
      expect(page).to have_content('New Tax Category')
      fill_in 'tax_category_name', with: 'sports goods'
      fill_in 'tax_category_description', with: 'sports goods desc'
      click_button 'Create'
      expect(page).to have_content('successfully created!')
    end

    it 'shows validation errors if there are any' do
      click_button 'Create'
      expect(page).to have_content("Name can't be blank")
    end
  end

  context 'admin editing a tax category' do
    it 'is able to update an existing tax category', js: true do
      create(:tax_category)
      click_link 'Tax Categories'
      within_row(1) { click_icon :edit }
      fill_in 'tax_category_description', with: 'desc 99'
      click_button 'Update'
      expect(page).to have_content('successfully updated!')
      expect(page).to have_content('desc 99')
    end
  end
end
