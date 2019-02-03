require 'spec_helper'

describe 'Storefront API v2 OrderStatus spec', type: :request do
  let!(:order) { create(:order, state: 'complete', completed_at: Time.current) }

  include_context 'API v2 tokens'

  describe '#show' do
    context 'as a guest user' do
      before { get "/api/v2/storefront/order_status/#{order.number}" }

      it_behaves_like 'returns valid cart JSON'
    end

    context 'as a guest user with token' do
      before { get "/api/v2/storefront/order_status/#{order.number}", headers: headers_order_token }

      it_behaves_like 'returns valid cart JSON'
    end

    context 'with non-existing Order number' do
      before { get '/api/v2/storefront/order_status/1' }

      it_behaves_like 'returns 404 HTTP status'
    end
  end
end
