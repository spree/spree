require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::TrackingCarriersController, type: :controller do
  render_views

  let(:store) { @default_store }
  let(:secret_api_key) { create(:api_key, :secret, store: store, scopes: %w[read_fulfillments write_fulfillments]) }

  before { request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token }

  describe 'GET #index' do
    it 'lists the registered carriers sorted by name' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      carriers = json_response['data']
      expect(carriers).to include('id' => 'inpost', 'name' => 'InPost')
      expect(carriers.map { |carrier| carrier['name'] }).to eq(carriers.map { |carrier| carrier['name'] }.sort)
    end

    it 'reflects carriers a host registers' do
      Spree.tracking_carriers['acme_courier'] = { name: 'Acme Courier', url: 'https://acme.test/:tracking' }

      get :index, as: :json

      expect(json_response['data']).to include('id' => 'acme_courier', 'name' => 'Acme Courier')
    ensure
      Spree.tracking_carriers.delete('acme_courier')
    end
  end
end
