require 'spec_helper'

describe 'Storefront API v2 OrderStatus spec', type: :request do
  let!(:order) { create(:order, state: 'complete', completed_at: Time.current) }

  include_context 'API v2 tokens'

  describe '#show' do
    context 'with existing Order number' do
      context 'as a guest user without token' do
        before { get "/api/v2/storefront/order_status/#{order.number}" }

        it_behaves_like 'returns 404 HTTP status'
      end

      context 'as a guest user with invalid token' do
        let(:headers_order_token) { { 'X-Spree-Order-Token' => 'WRONG' } }

        before { get "/api/v2/storefront/order_status/#{order.number}", headers: headers_order_token }

        it_behaves_like 'returns 404 HTTP status'
      end

      context 'as a guest user with valid token' do
        before { get "/api/v2/storefront/order_status/#{order.number}", headers: headers_order_token }

        it_behaves_like 'returns valid cart JSON'
      end
    end

    context 'with non-existing Order number' do
      before { get '/api/v2/storefront/order_status/1' }

      it_behaves_like 'returns 404 HTTP status'
    end
  end
end
