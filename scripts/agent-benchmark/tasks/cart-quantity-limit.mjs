import { runAcceptanceSpec } from '../lib/project.mjs'

// Covers every way a line can reach 11: one add, two adds, and an update.
//
// Adds must answer 422. A quantity update runs carts.upsert_items, where
// Spree skips a vetoed item and answers 200 with the reason in the cart's
// warnings (documented in customization/workflows.md), so an update passes
// with either a 422 or that warning. Either way the shopper must be told the
// maximum, and the line must keep its quantity.
const SPEC = `require 'rails_helper'

RSpec.describe 'Agent benchmark: cart quantity limit', type: :request do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :publishable, store: store) }
  let(:cart) { create(:cart, store: store) }
  let(:headers) { { 'x-spree-api-key' => api_key.token, 'x-spree-token' => cart.token } }
  let(:product) { create(:product_in_stock).tap { |p| p.default_variant.stock_levels.first.adjust_count_on_hand(100) } }
  let(:variant_id) { product.default_variant.prefixed_id }

  def add(quantity)
    post "/api/v3/store/carts/#{cart.prefixed_id}/items",
         params: { variant_id: variant_id, quantity: quantity }, headers: headers, as: :json
  end

  def line_quantity
    cart.reload.line_items.sum(:quantity)
  end

  # What the shopper is told: the error on a 422, the warnings on a 200.
  def shopper_message
    body = JSON.parse(response.body)
    return body['error'].to_json if response.status == 422

    Array(body['warnings']).to_json
  end

  it 'accepts 10 units' do
    add(10)
    expect(response).to have_http_status(:created)
    expect(line_quantity).to eq(10)
  end

  it 'rejects 11 units in one add' do
    add(11)
    expect(response).to have_http_status(:unprocessable_content)
    expect(shopper_message).to include('10')
    expect(line_quantity).to eq(0)
  end

  it 'rejects an add that takes an existing line past 10' do
    add(6)
    expect(response).to have_http_status(:created)
    add(6)
    expect(response).to have_http_status(:unprocessable_content)
    expect(shopper_message).to include('10')
    expect(line_quantity).to eq(6)
  end

  it 'rejects updating a line to 11' do
    add(5)
    item_id = JSON.parse(response.body)['items'].first['id']
    patch "/api/v3/store/carts/#{cart.prefixed_id}/items/#{item_id}",
          params: { quantity: 11 }, headers: headers, as: :json
    expect(response.status).to eq(422).or eq(200)
    expect(shopper_message).to include('10')
    expect(line_quantity).to eq(5)
  end
end
`

export default {
  id: 'cart-quantity-limit',
  title: 'Limit cart lines to 10 units with a workflow hook',
  project: { storefront: false },
  timeoutMinutes: 30,
  prompt: `We keep running out of stock to resellers. Limit every cart line to at most 10 units of the same variant.

It must hold however the quantity is reached: adding 11 at once, adding to a line that already has some, or changing a line's quantity. When the limit is hit, the Store API must answer with a validation error that tells the shopper the maximum, and the cart must stay as it was.

Add specs, and make sure the change is live in the running app.`,
  check: ({ projectDir }) => runAcceptanceSpec(projectDir, 'cart_quantity_limit', SPEC),
}
