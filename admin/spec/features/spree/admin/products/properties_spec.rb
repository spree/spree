require 'spec_helper'

describe 'Properties spec', type: :feature do
  stub_authorization!

  describe 'creating property' do
    before do
      visit spree.new_admin_property_path
    end

    it 'allows to create new property' do
      fill_in 'property_presentation', with: 'Country of Origin'
      select('Long text', from: 'Kind')
      click_button 'Create'

      expect(page).to have_content 'successfully created!'

      property = Spree::Property.last
      expect(property.presentation).to eq('Country of Origin')
      expect(property.name).to eq('country-of-origin')
      expect(property.kind).to eq('long_text')
    end
  end

  context 'listing properties', js: true do
    before do
      create(:property, name: 'ingredients', presentation: 'Ingredients', position: 2)
      create(:property, name: 'materials', presentation: 'Materials', position: 1)
    end

    it 'lists existing properties' do
      visit spree.admin_properties_path
      within('table') do
        within_row(1) do
          expect(page).to have_content('materials')
        end
        within_row(2) do
          expect(page).to have_content('ingredients')
        end
      end
    end

    it 'can change property display on from list view' do
      visit spree.admin_properties_path
      within_row(1) do
        expect(page).to have_content('materials')
        select 'Only on admin panel', from: 'property_display_on'
      end

      expect(page).to have_content('successfully updated!')

      property = Spree::Property.find_by(name: 'materials')
      expect(property.display_on).to eq('back_end')
    end
  end
end
