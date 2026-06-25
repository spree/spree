require 'spec_helper'

describe 'spree/admin/shared/_address.html.erb', type: :view do
  let(:country) { build_stubbed(:country, iso: 'US', name: 'United States of America') }
  let(:address) { build_stubbed(:address, country: country, firstname: 'Alexander', lastname: 'Kim') }

  before do
    view.extend Spree::BaseHelper
    I18n.backend.store_translations(:pl, spree: { country_names: { US: 'Stany Zjednoczone' } })
  end

  it 'renders the country name localized to the current locale' do
    I18n.with_locale(:pl) do
      render partial: 'spree/admin/shared/address', locals: { address: address }
    end

    expect(rendered).to include('Stany Zjednoczone')
    expect(rendered).not_to include('United States of America')
  end
end
