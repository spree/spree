require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::IntegrationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  # A representative carrier integration: one secret, one plain preference,
  # connection check controlled per example.
  let(:integration_class) do
    Class.new(Spree::Integration) do
      preference :api_key, :password
      preference :account_number, :string

      def self.name = 'TestIntegrations::Carrier'
      def self.integration_group = 'shipping'

      def can_connect?
        preferred_api_key == 'valid-key' || begin
          self.connection_error_message = 'invalid api key'
          false
        end
      end
    end
  end

  before do
    stub_const('TestIntegrations::Carrier', integration_class)
    Spree.integrations << 'TestIntegrations::Carrier'
  end

  after { Spree.integrations.delete('TestIntegrations::Carrier') }

  describe 'GET #types' do
    it 'lists registered types with schema and connected state' do
      get :types, as: :json

      expect(response).to have_http_status(:ok)
      entry = json_response['data'].find { |row| row['type'] == 'carrier' }
      expect(entry['name']).to eq('Carrier')
      expect(entry['group']).to eq('shipping')
      expect(entry['connected']).to be false
      expect(entry['preference_schema'].map { |f| f['key'] }).to match_array(%w[api_key account_number])
    end

    it 'marks connected types for the current store' do
      TestIntegrations::Carrier.create!(store: store, active: false)

      get :types, as: :json

      entry = json_response['data'].find { |row| row['type'] == 'carrier' }
      expect(entry['connected']).to be true
    end

    describe 'gallery metadata' do
      it 'serves the class description and no logo by default' do
        allow(TestIntegrations::Carrier).to receive(:description).and_return('Ships things')

        get :types, as: :json

        entry = json_response['data'].find { |row| row['type'] == 'carrier' }
        expect(entry['description']).to eq('Ships things')
        expect(entry['logo_url']).to be_nil
      end

      it 'serves the declared logo url untouched' do
        allow(TestIntegrations::Carrier).to receive(:logo_url).and_return('https://cdn.example.com/logo.svg')

        get :types, as: :json

        entry = json_response['data'].find { |row| row['type'] == 'carrier' }
        expect(entry['logo_url']).to eq('https://cdn.example.com/logo.svg')
      end
    end
  end

  describe 'POST #create' do
    it 'creates from the wire shorthand with typed preferences' do
      post :create, params: { type: 'carrier', preferences: { api_key: 'valid-key', account_number: '123' } }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['type']).to eq('carrier')
      expect(json_response['preferences']['account_number']).to eq('123')
      # Secrets never leave the server in plaintext.
      expect(json_response['preferences']['api_key']).to start_with('••••')

      integration = store.integrations.last
      expect(integration.preferred_api_key).to eq('valid-key')
      expect(integration.active).to be false
    end

    it 'rejects unregistered types' do
      post :create, params: { type: 'nonexistent', preferences: {} }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('unknown_integration_type')
    end

    it 'blocks activation when the connection fails' do
      post :create, params: { type: 'carrier', active: true, preferences: { api_key: 'wrong' } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['details']['base']).to include('invalid api key')
      expect(json_response['error']['message']).to eq('invalid api key')
    end
  end

  describe 'PATCH #update' do
    let!(:integration) { TestIntegrations::Carrier.create!(store: store, preferences: { api_key: 'valid-key' }) }

    it 'keeps the stored secret when the masked value round-trips' do
      patch :update, params: { id: integration.prefixed_id, preferences: { api_key: '••••-key', account_number: '55' } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(integration.reload.preferred_api_key).to eq('valid-key')
      expect(integration.preferred_account_number).to eq('55')
    end

    it 'activates when the connection succeeds' do
      patch :update, params: { id: integration.prefixed_id, active: true }, as: :json

      expect(response).to have_http_status(:ok)
      expect(integration.reload.active).to be true
    end

    it 'returns 404 for another store integration' do
      other = TestIntegrations::Carrier.create!(store: create(:store), preferences: { api_key: 'valid-key' })

      patch :update, params: { id: other.prefixed_id, active: true }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #test' do
    it 'reports a live connection check without persisting anything' do
      integration = TestIntegrations::Carrier.create!(store: store, preferences: { api_key: 'wrong' })

      post :test, params: { id: integration.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['connected']).to be false
      expect(json_response['error_message']).to eq('invalid api key')
    end
  end

  describe 'DELETE #destroy' do
    it 'disconnects the integration' do
      integration = TestIntegrations::Carrier.create!(store: store)

      delete :destroy, params: { id: integration.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(store.integrations.count).to eq(0)
    end
  end
end
