require 'spec_helper'

# What a customer gets back when their basket held several sellers' goods: one
# purchase, with the per-seller orders inside it.
RSpec.describe Spree::Api::V3::Store::CartsController, 'split checkout', type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:seller) { create(:seller, :approved, store: store) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
    create(:shipping_method) if Spree::DeliveryMethod.none?
  end

  # A basket of the operator's own goods plus one seller's — the mixed case.
  let(:cart) do
    cart = create(:cart_with_line_items, customer: user, store: store, line_items_count: 2)
    cart.update!(email: user.email, ship_address: create(:address), bill_address: create(:address))

    seller_line = cart.line_items.reload.last
    seller_line.variant.update!(seller: seller)
    seller_line.update_columns(seller_id: seller.id)

    cart.rebuild_fulfillments!
    cart.set_fulfillments_cost
    cart.reload.recalculate_totals!
    create(:payment, cart: cart, amount: cart.reload.total).tap(&:create_payment_profile)
    cart
  end

  it 'answers with the group rather than one of the orders' do
    post :complete, params: { id: cart.prefixed_id }

    expect(response).to have_http_status(:ok)
    expect(json_response['id']).to start_with('ogrp_')
    expect(json_response['orders'].size).to eq(2)
  end

  it 'shows the customer one total for the purchase' do
    post :complete, params: { id: cart.prefixed_id }

    expect(BigDecimal(json_response['total'])).to eq(cart.reload.total)
  end

  it 'nests each seller’s order with its own items and total' do
    post :complete, params: { id: cart.prefixed_id }

    orders = json_response['orders']
    expect(orders.map { |order| order['items'].size }).to all(eq(1))
    expect(orders.sum { |order| BigDecimal(order['total']) }).to eq(cart.reload.total)
  end

  it 'lets the client retry with the group id it was given' do
    post :complete, params: { id: cart.prefixed_id }
    group_id = json_response['id']

    post :complete, params: { id: group_id }

    expect(response).to have_http_status(:ok)
    expect(json_response['id']).to eq(group_id)
  end

  it 'leaves an unsplit checkout answering with a bare order' do
    plain = create(:cart_with_line_items, customer: user, store: store)
    plain.update!(email: user.email, ship_address: create(:address), bill_address: create(:address))
    plain.rebuild_fulfillments!
    plain.set_fulfillments_cost
    create(:payment, cart: plain, amount: plain.reload.total).tap(&:create_payment_profile)

    post :complete, params: { id: plain.prefixed_id }

    expect(response).to have_http_status(:ok)
    expect(json_response['id']).to start_with('or_')
  end
end
