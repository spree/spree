require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PayoutProvidersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists how this installation can pay sellers' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['id'] }).to include('Spree::PayoutProvider::System')
    end

    it 'names the one used when a store has chosen nothing' do
      get :index, as: :json

      default = json_response['data'].find { |row| row['default'] }

      expect(default['id']).to eq('Spree::PayoutProvider::System')
    end

    # Whether sellers must onboard with the provider changes what the
    # marketplace has to ask of them, so it is better known before the choice
    # than after.
    it 'says whether sellers must hold an account with each' do
      get :index, as: :json

      expect(json_response['data'].first).to include('requires_payout_account')
    end

    it 'says which are usable by this store today' do
      get :index, as: :json

      expect(json_response['data'].first).to include('available')
    end
  end
end
