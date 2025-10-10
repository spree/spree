require 'spec_helper'

describe 'Storefront API v2 OrderStatus spec', type: :request do
  let(:store) { @default_store }
  let!(:order) { create(:order, state: 'complete', completed_at: Time.current, store: store) }
  let(:store_2) { create(:store) }
  let(:order_2) { create(:order, state: 'complete', completed_at: Time.current, store: store_2) }

  include_context 'API v2 tokens'

  describe '#show' do
    context 'with existing Order number' do
      context 'as a guest user without token' do
        before { get "/api/v2/storefront/order_status/#{order.number}" }

        it_behaves_like 'returns 404 HTTP status'
      end

      context 'as a guest user with blank token' do
        let(:headers_order_token) { { 'X-Spree-Order-Token' => '' } }

        before { get "/api/v2/storefront/order_status/#{order.number}", headers: headers_order_token }

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

    context 'with Order from different Store' do
      before { get "/api/v2/storefront/order_status/#{order_2.number}", headers: headers_order_token }

      it_behaves_like 'returns 404 HTTP status'
    end
  end
end
