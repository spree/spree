require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StoreController, 'data sources', type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #data_sources' do
    it 'lists Spree own engines as available' do
      get :data_sources, as: :json

      expect(response).to have_http_status(:ok)
      pricing = json_response['data']['pricing_providers']
      expect(pricing.map { |row| row['key'] }).to include('internal')
      expect(pricing.find { |row| row['key'] == 'internal' }['available']).to be(true)
    end

    it 'offers the failure policies a merchant can choose between' do
      get :data_sources, as: :json

      expect(json_response['data']['failure_policies']).to contain_exactly('fallback', 'strict')
    end

    # A connector gem's provider is listed but not selectable until its
    # integration is connected, so the dashboard can say why rather than
    # leaving the merchant wondering where their ERP went.
    it 'marks a provider whose integration is not connected as unavailable' do
      needs_credentials = Class.new(Spree::PricingProvider::Base) do
        def self.key = 'acme_erp'
        def self.provider_name = 'Acme ERP'
        def self.integration_class = 'SpreeAcmeErp::Integration'
      end
      Spree.pricing_providers << needs_credentials

      get :data_sources, as: :json

      row = json_response['data']['pricing_providers'].find { |item| item['key'] == 'acme_erp' }
      expect(row['available']).to be(false)
      expect(row['integration_class']).to eq('SpreeAcmeErp::Integration')
    ensure
      Spree.pricing_providers.delete(needs_credentials)
    end
  end

  describe 'PATCH #update' do
    it 'saves the chosen providers and policies' do
      patch :update, params: {
        preferred_pricing_provider: 'internal',
        preferred_inventory_provider: 'internal',
        preferred_pricing_provider_failure_policy: 'fallback',
        preferred_inventory_provider_failure_policy: 'strict'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['preferred_pricing_provider_failure_policy']).to eq('fallback')
      expect(store.reload.preferred_inventory_provider_failure_policy).to eq('strict')
    end

    it 'refuses a policy that is neither falling back nor strict' do
      patch :update, params: { preferred_pricing_provider_failure_policy: 'ignore' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
