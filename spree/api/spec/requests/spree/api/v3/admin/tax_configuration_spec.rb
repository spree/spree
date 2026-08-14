require 'spec_helper'

# The reason /admin/tax_rates exists: rate rows are the whole configuration of
# the internal provider, so this walks the merchant's path — configure a rate
# through the API, then observe the tax it produces on a real cart.
RSpec.describe 'Admin tax configuration', type: :request do
  include_context 'API v3 Admin authenticated'

  let(:country) { Spree::Country.by_iso('DE') }
  let(:address) { create(:address, country: country, state: nil, state_name: 'Berlin') }
  let(:tax_category) { create(:tax_category) }

  let(:cart) do
    create(:cart_with_line_items, line_items_count: 1, store: store,
                                  ship_address: address, bill_address: address).tap do |cart|
      cart.line_items.first.update!(tax_category: tax_category)
    end
  end

  # Prices are quoted including German VAT, so the market is Germany.
  before { store.default_market.update!(countries: [country]) }

  # The publishable key the storefront reads with.
  let(:store_headers) { { 'x-spree-api-key' => create(:api_key, :publishable, store: store).token } }

  it 'configures a rate and produces the tax it describes' do
    post '/api/v3/admin/tax_rates',
         params: { name: 'German VAT', amount_percentage: 19, included_in_price: true,
                   tax_category_id: tax_category.prefixed_id, country_iso: 'DE' },
         headers: headers, as: :json

    expect(response).to have_http_status(:created)
    rate_id = JSON.parse(response.body)['id']
    expect(rate_id).to start_with('tax_')

    Spree::Carts::RecalculateTotals.call(cart: cart)

    expect(cart.tax_lines.reload.pluck(:amount, :taxability_reason, :country_iso, :provider_id)).to eq(
      [[BigDecimal('1.6'), 'standard_rated', 'DE', 'internal']]
    )
  end

  it 'still records a treatment when the rate is zero' do
    post '/api/v3/admin/tax_rates',
         params: { name: 'German VAT', amount_percentage: 19, included_in_price: true,
                   tax_category_id: tax_category.prefixed_id, country_iso: 'DE' },
         headers: headers, as: :json
    rate_id = JSON.parse(response.body)['id']

    Spree::Carts::RecalculateTotals.call(cart: cart)

    patch "/api/v3/admin/tax_rates/#{rate_id}", params: { amount: 0 }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)

    Spree::Carts::RecalculateTotals.call(cart: cart.reload)

    tax_line = cart.tax_lines.reload.sole
    expect(tax_line.amount).to eq(0)
    expect(tax_line.taxability_reason).to eq('zero_rated')
  end

  it 'shows the storefront the tax on a line, without the admin treatment fields' do
    post '/api/v3/admin/tax_rates',
         params: { name: 'German VAT', amount_percentage: 19, included_in_price: true,
                   tax_category_id: tax_category.prefixed_id, country_iso: 'DE' },
         headers: headers, as: :json

    Spree::Carts::RecalculateTotals.call(cart: cart)

    get "/api/v3/store/carts/#{cart.prefixed_id}?expand=items.tax_lines",
        headers: store_headers.merge('x-spree-token' => cart.token), as: :json

    expect(response).to have_http_status(:ok)
    tax_lines = JSON.parse(response.body)['items'].first['tax_lines']
    expect(tax_lines.length).to eq(1)
    expect(tax_lines.first).to include('label', 'rate', 'amount', 'included')
    expect(tax_lines.first['included']).to be(true)
    expect(tax_lines.first).not_to have_key('taxability_reason')
    expect(tax_lines.first).not_to have_key('country_iso')
  end
end
