require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::StoreController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'GET #show' do
    it 'returns ok' do
      get :show

      expect(response).to have_http_status(:ok)
    end

    it 'exposes customer-facing branding and config' do
      get :show

      expect(json_response).to include(
        'name' => store.name,
        'default_currency' => store.default_currency,
        'default_locale' => store.default_locale
      )
      expect(json_response['url']).to eq(store.storefront_url)
      expect(json_response['supported_currencies']).to be_an(Array)
      expect(json_response['supported_locales']).to be_an(Array)
      expect(json_response).to have_key('logo_url')
    end

    it 'never exposes admin-only fields' do
      # Regression guard for the Store/Admin serializer split: Store must
      # stay a strict subset, never back-office data (mail settings,
      # notification addresses, admin prefs, internal metadata, timestamps).
      get :show

      expect(json_response.keys).not_to include(
        'mailer_logo_url', 'mail_from_address', 'customer_support_email',
        'new_order_notifications_email', 'preferred_send_consumer_transactional_emails',
        'preferred_admin_locale', 'preferred_timezone', 'preferred_weight_unit',
        'preferred_unit_system', 'preferred_storefront_access', 'preferred_guest_checkout',
        'available_locales', 'metadata', 'created_at', 'updated_at'
      )
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :show

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
