require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Orders::InvoicesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:order) { create(:completed_order_with_totals, customer: user, store: store) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
    create(:invoice, order: order)
    create(:invoice, :receipt, order: order)
  end

  describe 'GET #index' do
    it_behaves_like 'a list without N+1 queries' do
      subject { get :index, params: { order_id: order.prefixed_id }, as: :json }
    end

    it 'hides staff-only fields' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(json_response['data'].first.keys).not_to include('source', 'sent_at', 'uploaded_by_id', 'metadata')
    end

    it "lists a guest order's invoices for the holder of its token" do
      guest_order = create(:completed_order_with_totals, customer: nil, store: store)
      guest_invoice = create(:invoice, order: guest_order)
      request.headers['Authorization'] = nil
      request.headers['x-spree-token'] = guest_order.token

      get :index, params: { order_id: guest_order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['id'] }).to eq([guest_invoice.prefixed_id])
    end
  end
end
