require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::TaxProvidersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the built-in engine with the domains it cannot handle' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      internal = json_response['data'].find { |provider| provider['id'] == 'internal' }
      expect(internal['name']).to eq('Spree tax rates')
      expect(internal['available']).to be(true)
      expect(internal['default']).to be(true)
      expect(internal['unsupported_capabilities'].map { |capability| capability['key'] }).to(
        contain_exactly('us_local_tax', 'reverse_charge', 'oss_thresholds', 'proportional_delivery_tax')
      )
    end

    it 'gives each limit a label and the consequence a merchant can act on' do
      get :index, as: :json

      internal = json_response['data'].find { |provider| provider['id'] == 'internal' }
      reverse_charge = internal['unsupported_capabilities'].find { |c| c['key'] == 'reverse_charge' }

      expect(reverse_charge['label']).to eq('EU reverse charge')
      expect(reverse_charge['description']).to include('charged tax instead of receiving a zero-rated invoice')
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

      row = json_response['data'].find { |provider| provider['id'] == 'spec_unconnected_provider' }
      expect(row['available']).to be(false)
      expect(row['default']).to be(false)
    ensure
      Spree.tax_providers.delete(SpecUnconnectedProvider)
    end

    it 'says whether each engine offers a tax code search' do
      get :index, as: :json

      internal = json_response['data'].find { |provider| provider['id'] == 'internal' }
      expect(internal['tax_code_lookup']).to be(false)
    end
  end

  describe 'GET #tax_codes' do
    let(:searches) { [] }

    before do
      queries = searches
      stub_const('SpecSearchableProvider', Class.new(Spree::TaxProvider::Base) do
        define_singleton_method(:tax_codes) do |store, query:|
          queries << [store, query]
          [{ code: 'PC040100', description: 'Clothing and related products' }]
        end
      end)
      Spree.tax_providers << SpecSearchableProvider
    end

    after { Spree.tax_providers.delete(SpecSearchableProvider) }

    it "searches the engine's codes for the current store" do
      get :tax_codes, params: { id: 'spec_searchable_provider', q: ' clothing ' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to eq([{ 'code' => 'PC040100', 'description' => 'Clothing and related products' }])
      expect(searches).to eq([[store, 'clothing']])
    end

    it 'answers nothing for a query too short to search, without asking the engine' do
      get :tax_codes, params: { id: 'spec_searchable_provider', q: 'c' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to eq([])
      expect(searches).to be_empty
    end

    it 'answers nothing for an engine with no codes to search' do
      get :tax_codes, params: { id: 'internal', q: 'clothing' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to eq([])
    end

    # The registry may hold a provider by class name rather than as a class.
    it 'finds an engine registered by name' do
      Spree.tax_providers.delete(SpecSearchableProvider)
      Spree.tax_providers << 'SpecSearchableProvider'

      get :tax_codes, params: { id: 'spec_searchable_provider', q: 'clothing' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].sole['code']).to eq('PC040100')
    ensure
      Spree.tax_providers.delete('SpecSearchableProvider')
    end

    it 'answers 404 for an engine that is not installed' do
      get :tax_codes, params: { id: 'no_such_engine', q: 'clothing' }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'answers an engine outage the way every tax failure is answered' do
      SpecSearchableProvider.define_singleton_method(:tax_codes) do |_store, query:|
        raise Spree::Tax::ProviderUnavailable.new('timed out', provider_key: 'spec')
      end

      get :tax_codes, params: { id: 'spec_searchable_provider', q: 'clothing' }, as: :json

      expect(response).to have_http_status(:service_unavailable)
      expect(json_response['error']['code']).to eq('tax_provider_unavailable')
    end
  end
end
