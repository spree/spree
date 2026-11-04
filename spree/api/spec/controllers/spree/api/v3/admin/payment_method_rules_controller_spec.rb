require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PaymentMethodRulesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #types' do
    it 'lists registered rule kinds with their preferences schema' do
      get :types, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['type'] }).to contain_exactly(
        'channel_rule', 'market_rule', 'order_total_rule', 'customer_group_rule', 'company_rule'
      )
      company = json_response['data'].find { |row| row['type'] == 'company_rule' }
      expect(company['schema']['properties'].keys).to contain_exactly('company_ids', 'company_orders_only')
    end
  end
end
