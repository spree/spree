# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::DeliveryProfilesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:default_profile) { store.default_delivery_profile }
  let!(:custom_profile) { create(:delivery_profile, store: store, name: 'Oversized') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns delivery profiles with the default first, then by position' do
      custom_profile.insert_at(1)

      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].first['default']).to be(true)
      expect(json_response['data'].pluck('name')).to eq([default_profile.name, 'Oversized'])
    end
  end
end
