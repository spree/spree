require 'spec_helper'

describe 'API keys', type: :feature do
  stub_authorization!

  let!(:oauth_application) { create(:oauth_application, name: 'Test app') }

  it 'renders a list of applications' do
    visit '/admin/oauth_applications'

    expect(page).to have_content('Test app')
  end

  it 'can create a new app', js: true do
    visit '/admin/oauth_applications/new'

    fill_in 'Name', with: 'My app'
    click_button 'Create'

    expect(page).to have_content('Client ID')
    expect(page).to have_content('Client Secret')
    expect(page).to have_content(Spree::OauthApplication.last.uid)
  end

  it 'can modify existing app' do
    visit "/admin/oauth_applications/#{oauth_application.id}/edit"

    fill_in 'Name', with: 'New name'
    within('#page-header') { click_button 'Update' }

    expect(page).to have_content('successfully updated!')
    expect(page).to have_content('New name')
  end
end
