require 'spec_helper'

# Saving a settings page PATCHes the whole store. The store's legacy currency
# and locale columns can lag behind the default market once it is edited in
# Settings → Markets, and that save must not write them back onto the market.
RSpec.describe 'Admin store update and the default market', type: :request do
  include_context 'API v3 Admin'

  let(:market) { store.default_market }

  before do
    store.update_columns(default_currency: 'USD', default_locale: 'en', supported_locales: nil)
    market.update!(currency: 'EUR', default_locale: 'nl', supported_locales: 'en,nl')
  end

  it 'leaves the default market currency and locales untouched' do
    patch '/api/v3/admin/store',
          params: { mail_from_address: 'shop@example.com' },
          headers: bearer_headers,
          as: :json

    expect(response).to have_http_status(:ok)
    market.reload
    expect(market.currency).to eq('EUR')
    expect(market.default_locale).to eq('nl')
    expect(market.supported_locales_list).to eq(%w[en nl])
  end
end
