require 'spec_helper'
require 'shared_examples/api_v2/base'
require 'shared_examples/api_v2/current_order'

describe 'Storefront API v2 OrderStatus spec', type: :request do
  let!(:guest_token) { 'guest_token' }
  let!(:order) { create(:order, state: 'complete', token: guest_token) }

  describe '#show' do
    context 'as a guest user' do
      before { get "/api/v2/storefront/order_status/#{order.number}" }

      it_behaves_like 'returns valid cart JSON'
    end

    context 'with non-existing Order number' do
      before { get '/api/v2/storefront/order_status/1' }

      it_behaves_like 'returns 404 HTTP status'
    end
  end
end
