require 'spec_helper'

describe 'Roles', type: :feature do
  stub_authorization!

  before do
    create(:role, name: 'admin')
    create(:role, name: 'user')
    visit spree.admin_path
    click_link 'Configuration'
    # Crap workaround for animation to finish expanding so click doesn't hit ReimbursementTypes.
    sleep 1
    click_link 'Roles'
  end

  context 'show' do
    it 'displays existing roles' do
      within_row(1) { expect(page).to have_content('admin') }
      within_row(2) { expect(page).to have_content('user') }
    end
  end

  context 'create' do
    it 'is able to create a new role' do
      within find('#contentHeader') do
        click_link 'admin_new_role_link'
      end
      
      expect(page).to have_content('New Role')
      fill_in 'role_name', with: 'blogger'
      click_button 'Create'
      expect(page).to have_content('successfully created!')
    end
  end

  context 'edit' do
    it 'is not able to edit the admin role' do
      within_row(1) do
        expect(find('td:nth-child(2)')).not_to have_selector(:css, '.icon-edit')
        expect(find('td:nth-child(2)')).not_to have_selector(:css, '.icon-delete')
      end
    end
    it 'is able to edit the user role' do
      within_row(2) do
        expect(find('td:nth-child(2)')).to have_selector(:css, '.icon-edit')
        expect(find('td:nth-child(2)')).to have_selector(:css, '.icon-delete')
      end
    end
  end
end
