require 'spec_helper'

describe 'API V2 Number Resources Spec' do
  include_context 'Platform API v2'

  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  let(:order) { create(:order, store: store) }

  describe 'orders#show' do
    context 'can fetch order by the number' do
      before do
        get "/api/v2/platform/orders/#{order.number}", headers: bearer_token
      end

      it_behaves_like 'returns 200 HTTP status'
    end
  end

  describe 'shipments#show' do
    let(:shipment) { create(:shipment, order: order) }

    context 'can fetch order by the number' do
      before do
        get "/api/v2/platform/shipments/#{shipment.number}", headers: bearer_token
      end

      it_behaves_like 'returns 200 HTTP status'
    end
  end

  describe 'payments#show' do
    let(:payment) { create(:payment, order: order) }

    context 'can fetch order by the number' do
      before do
        get "/api/v2/platform/payments/#{payment.number}", headers: bearer_token
      end

      it_behaves_like 'returns 200 HTTP status'
    end
  end
end
