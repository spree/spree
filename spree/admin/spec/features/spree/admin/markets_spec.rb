require 'spec_helper'

RSpec.describe 'Markets', type: :feature do
  stub_authorization!

  let(:store) { @default_store }
  # @default_country is the seeded US country; reuse it so the flag/name are deterministic.
  let(:country) { @default_country }

  # Markets selects only offer countries with shipping coverage, so wire up a
  # shipping zone + method for the country first.
  before do
    zone = create(:zone, name: 'US Shipping Zone', kind: 'country')
    zone.zone_members.create!(zoneable: country)
    create(:shipping_method, zones: [zone])
  end

  scenario 'index renders the default locale as a localized label' do
    create(:market, store: store, currency: 'USD', default_locale: 'en', countries: [country])

    visit spree.admin_markets_path

    # The default_locale column localizes "en" instead of rendering the raw code.
    expect(page).to have_content('EN — English')
    expect(page).not_to have_selector('td', exact_text: 'en')
  end

  scenario 'new form renders localized country, currency, and locale options' do
    visit spree.new_admin_market_path

    # Country option is prefixed with the flag emoji + localized name.
    expect(page).to have_select(Spree.t(:countries))
    expect(page).to have_content('🇺🇸')
    expect(page).to have_content('United States')

    expect(page).to have_select(Spree.t(:currency), with_options: ['EUR — Euro'])
    expect(page).to have_select('market_default_locale', with_options: ['EN — English'])
  end
end
