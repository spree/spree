require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::DeliveryMethodRulesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #types' do
    it 'lists registered rule kinds with preference schemas' do
      get :types, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['type'] }).to contain_exactly('item_total_rule', 'weight_rule', 'excluded_products_rule', 'channel_rule',
                       'volume_rule', 'company_rule')
      item_total = json_response['data'].find { |row| row['type'] == 'item_total_rule' }
      expect(item_total['preference_schema'].map { |field| field['key'] }).to contain_exactly('minimum_amount', 'maximum_amount')

      excluded = json_response['data'].find { |row| row['type'] == 'excluded_products_rule' }
      expect(excluded['association_fields']).to eq(['product_ids'])
    end
  end
end
