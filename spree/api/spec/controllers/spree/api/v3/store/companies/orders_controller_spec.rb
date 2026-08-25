require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Companies::OrdersController, type: :controller do
  render_views

  include_context 'API v3 Store authenticated'

  let(:company) { create(:company, store: store) }
  let(:division) { create(:company, store: store, kind: 'division', parent: company) }

  before do
    create(:company_membership, company: company, customer: user)
    request.headers.merge!(headers)
  end

  describe 'GET #index' do
    it 'lists completed purchases across the subtree, not just the node' do
      node_order = create(:completed_order_with_totals, store: store)
      node_order.update_columns(company_id: company.id)
      subtree_order = create(:completed_order_with_totals, store: store)
      subtree_order.update_columns(company_id: division.id)
      create(:completed_order_with_totals, store: store) # consumer order

      get :index, params: { company_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |row| row['id'] }
      expect(ids).to contain_exactly(node_order.prefixed_id, subtree_order.prefixed_id)
    end

    it 'scopes a division to its own subtree' do
      parent_order = create(:completed_order_with_totals, store: store)
      parent_order.update_columns(company_id: company.id)

      get :index, params: { company_id: division.prefixed_id }, as: :json

      expect(json_response['data']).to be_empty
    end

    it '404s a node without standing' do
      get :index, params: { company_id: create(:company, store: store).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
