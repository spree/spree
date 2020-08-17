require 'spec_helper'

describe 'Promotion with user rule', type: :feature, js: true do
  stub_authorization!

  let!(:first_user) { create(:user, email: 'first@example.com') }
  let!(:second_user) { create(:user, email: 'second@example.com') }
  let!(:third_user) { create(:user, email: 'third@example.com') }
  let!(:fourth_user) { create(:user, email: 'fourth@testing.com') }
  let!(:fifth_user) { create(:user, email: 'fifth@testing.com') }

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

    expect(page).not_to have_content('second@example.com')
    expect(page).not_to have_content('third@example.com')

    within('#select2-drop') do
      first('.select2-result').click
    end

    wait_for { !page.has_button?('Update') }
    within('#rules_container') { click_button 'Update' }

    expect(page).to have_content('Promotion "User promotion" has been successfully updated!')
  end

  it 'user dropdown shows user emails that matches user query #1' do
    fill_in 'Name', with: 'User promotion'
    click_button 'Create'

    select2 'User', from: 'Add rule of type', match: :first
    within('#rule_fields') { click_button 'Add' }

    find('.user_picker').fill_in with: 'example'

    expect(page).to have_content('first@example.com')
    expect(page).to have_content('second@example.com')
    expect(page).to have_content('third@example.com')
  end

  it 'user dropdown shows user emails that matches user query #2' do
    fill_in 'Name', with: 'User promotion'
    click_button 'Create'

    select2 'User', from: 'Add rule of type', match: :first
    within('#rule_fields') { click_button 'Add' }

    find('.user_picker').fill_in with: 'test'

    expect(page).to have_content('fourth@testing.com')
    expect(page).to have_content('fifth@testing.com')
  end
end
