require 'rails_helper'

RSpec.describe 'Cart quantity limit', type: :request do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :publishable, store: store) }
  let(:cart) { create(:cart, store: store) }
  let(:headers) { { 'x-spree-api-key' => api_key.token, 'x-spree-token' => cart.token } }
  let(:product) { create(:product_in_stock).tap { |p| p.default_variant.stock_levels.first.adjust_count_on_hand(100) } }

  def add(quantity)
    post "/api/v3/store/carts/#{cart.prefixed_id}/items",
         params: { variant_id: product.default_variant.prefixed_id, quantity: quantity }, headers: headers, as: :json
  end

  it 'allows 10 units on a line' do
    add(4)
    add(6)
    expect(response).to have_http_status(:created)
    expect(cart.reload.line_items.sum(:quantity)).to eq(10)
  end

  it 'refuses an add that takes a line past 10' do
    add(6)
    add(5)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('at most 10')
    expect(cart.reload.line_items.sum(:quantity)).to eq(6)
  end

  it 'refuses setting a line to 11' do
    add(5)
    item_id = JSON.parse(response.body)['items'].first['id']
    patch "/api/v3/store/carts/#{cart.prefixed_id}/items/#{item_id}",
          params: { quantity: 11 }, headers: headers, as: :json
    expect(response.body).to include('at most 10')
    expect(cart.reload.line_items.sum(:quantity)).to eq(5)
  end
end
