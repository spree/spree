require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Checkout::PaymentMethodsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:order) { create(:order_with_line_items, user: user, store: store, state: 'payment') }
  let!(:payment_method) { create(:credit_card_payment_method, stores: [store], display_on: 'both') }
  let!(:backend_only_pm) { create(:credit_card_payment_method, stores: [store], display_on: 'back_end') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
    it 'returns available payment methods for the cart' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |pm| pm['id'] }).to include(payment_method.prefixed_id)
    end

    it 'excludes backend-only payment methods' do
      get :index

      expect(json_response['data'].map { |pm| pm['id'] }).not_to include(backend_only_pm.prefixed_id)
    end

    it 'includes session_required in the response' do
      get :index

      pm = json_response['data'].find { |p| p['id'] == payment_method.prefixed_id }
      expect(pm).to have_key('session_required')
    end

    it 'includes payment method count in meta' do
      get :index

      expect(json_response['meta']['count']).to be_present
    end

    context 'with spree token (guest)' do
      let(:guest_order) { create(:order_with_line_items, store: store, user: nil, state: 'payment') }

      before { request.headers['Authorization'] = nil }

      it 'returns payment methods with valid spree token' do
        request.headers['x-spree-token'] = guest_order.token
        get :index

        expect(response).to have_http_status(:ok)
        expect(json_response['data']).to be_present
      end

      it 'returns not found without spree token' do
        get :index

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
