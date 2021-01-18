require 'spec_helper'

describe 'Option Type edit spec', type: :feature, js: true do
  stub_authorization!

  let(:option_type) { create(:option_type, filterable: false) }

  context 'editing option type' do
    before do
      visit spree.edit_admin_option_type_path(option_type)
    end

    it 'allows to update filtering attribute of option type' do
      expect(page).to have_unchecked_field('option_type_filterable')

      check('option_type_filterable')
      click_button 'Update'

      expect(page).to have_content 'successfully updated!'

      within("#spree_option_type_#{option_type.id}") { click_icon(:edit) }
      expect(page).to have_checked_field('option_type_filterable')
    end
  end
end
