require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::OrderGroupsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:seller) { create(:seller, :approved, store: store, name: 'Sparks Audio') }
  let!(:group) { create(:order_group, store: store) }
  let!(:first_party_order) { create(:order, store: store, order_group: group, total: 30) }
  let!(:seller_order) { create(:order, store: store, order_group: group, seller: seller, total: 20) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the store’s groups' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(1)
      expect(json_response['data'].first['number']).to eq(group.number)
    end

    it 'does not list another store’s groups' do
      create(:order_group, store: create(:store))

      get :index

      expect(json_response['data'].size).to eq(1)
    end
  end

  describe 'GET #show' do
    it 'reports what the checkout came to and who it reached' do
      get :show, params: { id: group.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(BigDecimal(json_response['total'])).to eq(50)
      expect(json_response['seller_count']).to eq(1)
      expect(json_response['includes_first_party']).to be(true)
    end

    it 'nests the orders it holds' do
      get :show, params: { id: group.prefixed_id }

      numbers = json_response['orders'].map { |order| order['number'] }
      expect(numbers).to contain_exactly(first_party_order.number, seller_order.number)
    end
  end

  # Read-only by routing: a group records a checkout that already happened.
  describe 'writes' do
    it 'has no create route' do
      expect { post :create, params: {} }.to raise_error(ActionController::UrlGenerationError)
    end

    it 'has no destroy route' do
      expect { delete :destroy, params: { id: group.prefixed_id } }.to raise_error(ActionController::UrlGenerationError)
    end
  end
end
