require 'spec_helper'

describe 'setting locale', type: :feature do
  stub_authorization!

  before do
    I18n.locale = I18n.default_locale
    Spree::Backend::Config[:locale] = 'fr'
  end

  after do
    I18n.locale = I18n.default_locale
    Spree::Backend::Config[:locale] = 'en'
  end

  it 'is in french' do
    visit spree.admin_path
    click_link 'Ordres'
    expect(page).to have_content('Ordres')
  end
end
