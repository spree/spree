require 'spec_helper'

describe 'Pages Index', type: :feature do
  stub_authorization!

  context 'when no pages are present' do
    before do
      visit spree.admin_menus_path
    end

    it 'prompts the user to create a menu' do
      expect(page).to have_text 'You have no Menus, click the Add New Menu button to create your first Menu.'
    end
  end
end
