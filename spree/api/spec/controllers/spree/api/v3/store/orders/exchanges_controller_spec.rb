require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Orders::ExchangesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:order) { create(:shipped_order, customer: user, store: store) }
  let(:unit) { order.fulfillment_items.first }
  let(:replacement) { create(:variant, product: unit.variant.product) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
    Spree.hooks.register('exchanges.create.validate', 'Spree::Returns::ReturnableValidator')
  end

  def open_exchange(order_id: order.prefixed_id, variant: replacement)
    post :create, params: {
      order_id: order_id,
      items: [{ fulfillment_item_id: unit.prefixed_id, new_variant_id: variant.prefixed_id, quantity: 1 }]
    }, as: :json
  end

  it 'lets a customer swap a unit for another variant of the same product' do
    open_exchange

    expect(response).to have_http_status(:created)
    expect(order.reload.exchanges.count).to eq(1)
  end

  it 'refuses a replacement that cannot be bought' do
    replacement.update_columns(discontinue_on: 1.day.ago)

    open_exchange

    expect(response).to have_http_status(:unprocessable_content)
    expect(order.reload.exchanges).to be_empty
  end

  it "refuses a replacement with no price in the order's currency" do
    replacement.prices.where(currency: order.currency).delete_all

    open_exchange

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'refuses a replacement sold by another seller' do
    replacement.update_columns(seller_id: create(:seller, store: store).id)

    open_exchange

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'refuses a unit sold as non-returnable' do
    unit.line_item.update_columns(returnable: false)

    open_exchange

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_response.dig('error', 'message')).to include('non-returnable')
  end

  describe 'GET #index' do
    subject { get :index, params: { order_id: order.prefixed_id }, as: :json }

    it_behaves_like 'a list without N+1 queries' do
      let!(:records) { create_list(:exchange, 2, order: order) }
    end
  end

  it "does not reach another customer's order" do
    other = create(:shipped_order, store: store)

    get :index, params: { order_id: other.prefixed_id }, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'lets a guest in with the order token' do
    guest_order = create(:shipped_order, store: store, customer: nil)
    request.headers['Authorization'] = nil
    request.headers['X-Spree-Token'] = guest_order.token

    get :index, params: { order_id: guest_order.prefixed_id }, as: :json

    expect(response).to have_http_status(:ok)
  end
end
