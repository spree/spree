require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::TaxProvidersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the built-in engine with the domains it cannot handle' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      internal = json_response['data'].find { |provider| provider['id'] == 'Spree::TaxProvider::Internal' }
      expect(internal['name']).to eq('Internal')
      expect(internal['available']).to be(true)
      expect(internal['default']).to be(true)
      expect(internal['unsupported_capabilities']).to contain_exactly('us_local_tax', 'reverse_charge', 'oss_thresholds')
    end

    it 'reports an engine whose credentials are missing as unavailable' do
      stub_const('SpecUnconnectedProvider', Class.new(Spree::TaxProvider::Base) do
        def self.available_for_store?(_store)
          false
        end

        def self.unsupported_capabilities
          []
        end
      end)
      Spree.tax_providers << SpecUnconnectedProvider

      get :index, as: :json

      row = json_response['data'].find { |provider| provider['id'] == 'SpecUnconnectedProvider' }
      expect(row['available']).to be(false)
      expect(row['default']).to be(false)
    ensure
      Spree.tax_providers.delete(SpecUnconnectedProvider)
    end
  end
end
