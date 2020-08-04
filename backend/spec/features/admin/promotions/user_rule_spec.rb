require 'spec_helper'

describe 'Promotion with user rule', type: :feature, js: true do
  stub_authorization!

  let!(:first_user) { create(:user, email: 'first@example.com') }
  let!(:second_user) { create(:user, email: 'second@example.com') }
  let!(:third_user) { create(:user, email: 'third@example.com') }

  before do
    visit spree.new_admin_promotion_path
  end

  it 'creates new promotion with user rule' do
    fill_in 'Name', with: 'User promotion'
    click_button 'Create'

    expect(page).to have_content('Promotion "User promotion" has been successfully created!')

    select2 'User', from: 'Add rule of type', match: :first
    within('#rule_fields') { click_button 'Add' }

    find('.user_picker').fill_in with: 'first'
    expect(page).to have_content('first@example.com')

    within('#select2-drop') do
      first('.select2-result').click
    end

    wait_for { !page.has_button?('Update') }
    within('#rules_container') { click_button 'Update' }

    expect(page).to have_content('Promotion "User promotion" has been successfully updated!')
  end
end
