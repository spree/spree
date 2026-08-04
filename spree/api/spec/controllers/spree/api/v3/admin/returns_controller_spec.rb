require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ReturnsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:shipped_order, store: store) }
  let!(:pending_return) { create(:return, store: store, order: order) }
  let!(:received) { create(:received_return, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists returns across every order in the store' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |r| r['id'] }).
        to contain_exactly(pending_return.prefixed_id, received.prefixed_id)
    end

    # The whole point of the cross-order list: "what is awaiting receipt".
    it 'filters by status' do
      get :index, params: { q: { status_eq: 'received' } }, as: :json

      expect(json_response['data'].map { |r| r['id'] }).to eq([received.prefixed_id])
    end

    it 'does not leak another store' do
      other = create(:return, store: create(:store))

      get :index, as: :json

      expect(json_response['data'].map { |r| r['id'] }).not_to include(other.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'returns one record' do
      get :show, params: { id: pending_return.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['number']).to eq(pending_return.number)
    end
  end

  it 'does not expose a create route' do
    expect { post :create, params: {}, as: :json }.to raise_error(ActionController::UrlGenerationError)
  end
end
