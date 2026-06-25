require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::LocalesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before do
    configure_supported_locales(store, %w[en de ar])
    request.headers.merge!(headers)
  end

  describe 'GET #index' do
    it 'lists supported locales with default and rtl flags' do
      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      locales = json_response['data']
      expect(locales.map { |l| l['code'] }).to match_array(%w[en de ar])

      en = locales.find { |l| l['code'] == 'en' }
      expect(en['default']).to be(true)
      expect(en['rtl']).to be(false)

      ar = locales.find { |l| l['code'] == 'ar' }
      expect(ar['default']).to be(false)
      expect(ar['rtl']).to be(true)
    end
  end
end
