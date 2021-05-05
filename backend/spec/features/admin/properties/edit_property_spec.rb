require 'spec_helper'

describe 'Property edit spec', type: :feature, js: true do
  stub_authorization!

  let(:property) { create(:property, filterable: false) }

  context 'editing option type' do
    before do
      visit spree.edit_admin_property_path(property)
    end

    it 'allows to update filtering attribute of option type' do
      expect(page).to have_unchecked_field('property_filterable')

      check('property_filterable')
      click_button 'Update'

      expect(page).to have_content 'successfully updated!'

      within("#spree_property_#{property.id}") { click_icon(:edit) }
      expect(page).to have_checked_field('property_filterable')
    end
  end
end
