require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StoreController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  # `@default_store` is a shared in-memory object across the suite; reload it
  # so each example starts from the persisted state and isn't tripped up by
  # AR change tracking from earlier rolled-back updates.
  before { store.reload }
  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    subject { get :show, as: :json }

    it 'returns ok' do
      subject
      expect(response).to have_http_status(:ok)
    end

    # The dashboard shell (store name, logo, timezone, currencies, locales)
    # can't render without this, so reading the store is not gated on the
    # settings permission — only writing is.
    context 'as a staffer without any settings permission' do
      let(:staffer) do
        create(:admin_user, :without_admin_role).tap do |user|
          user.role_users.create!(
            role: create(:role, name: 'orders_only', permissions: %w[write_orders]),
            resource: store
          )
        end
      end
      let(:headers) do
        { 'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(staffer, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}" }
      end

      it 'still reads the store' do
        subject
        expect(response).to have_http_status(:ok)
        expect(json_response['name']).to eq(store.name)
      end

      it 'cannot update it' do
        patch :update, params: { name: 'Renamed' }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(store.reload.name).not_to eq('Renamed')
      end
    end

    # The shell-data exemption is JWT-only: a scope-limited integration key
    # has no business reading operational settings (support/notification
    # emails, routing) it was never granted, so secret keys still need
    # `read_settings`.
    context 'via a secret API key without a settings scope' do
      let(:secret_api_key) { create(:api_key, :secret, store: store, scopes: %w[read_orders]) }
      let(:headers) { { 'x-spree-api-key' => secret_api_key.plaintext_token } }

      it 'is denied' do
        subject
        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['details']['required_scope']).to eq('read_settings')
      end

      it 'cannot update it' do
        patch :update, params: { name: 'Renamed' }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'via a secret API key with the settings scope' do
      let(:secret_api_key) { create(:api_key, :secret, store: store, scopes: %w[read_settings]) }
      let(:headers) { { 'x-spree-api-key' => secret_api_key.plaintext_token } }

      it 'reads the store' do
        subject
        expect(response).to have_http_status(:ok)
        expect(json_response['name']).to eq(store.name)
      end
    end

    it 'serializes the prefixed id, not the raw integer DB id' do
      # Regression: a previous version of the serializer listed `:id` in
      # `attributes`, which overrode `BaseSerializer#id` and exposed the
      # raw integer primary key.
      subject
      expect(json_response['id']).to eq(store.prefixed_id)
      expect(json_response['id']).to start_with('store_')
      expect(json_response['id']).not_to eq(store.id)
      expect(json_response['id']).not_to eq(store.id.to_s)
    end

    it 'returns the store name' do
      subject
      expect(json_response['name']).to eq(store.name)
    end

    context 'when the store has no allowed origins' do
      it 'serializes url from storefront_url (falling back to formatted_url)' do
        # Regression: the previous serializer exposed the raw `url` column,
        # not the customer-facing storefront URL.
        subject
        expect(json_response['url']).to eq(store.storefront_url)
        expect(json_response['url']).to eq(store.formatted_url)
      end
    end

    context 'when the store has an allowed origin' do
      before do
        store.allowed_origins.create!(origin: 'https://shop.example.com')
      end

      it 'serializes url from the first allowed origin' do
        subject
        expect(json_response['url']).to eq('https://shop.example.com')
      end
    end

    it 'includes computed default_currency, default_locale and supported lists' do
      subject
      expect(json_response).to include(
        'default_currency' => store.default_currency,
        'default_locale' => store.default_locale
      )
      expect(json_response['supported_currencies']).to be_an(Array)
      expect(json_response['supported_locales']).to be_an(Array)
    end

    it 'exposes the full canonical set of translatable locales' do
      subject
      expect(json_response['available_locales']).to eq(Spree::Locales::ALL)
      # Locales a store can adopt even if not yet in supported_locales.
      expect(json_response['available_locales']).to include('pt-BR', 'zh-CN', 'en-GB')
    end

    it 'exposes the email-section attributes' do
      subject
      expect(json_response).to include(
        'mail_from_address' => store.mail_from_address,
        'customer_support_email' => store.customer_support_email,
        'new_order_notifications_email' => store.new_order_notifications_email,
        'preferred_send_consumer_transactional_emails' => store.preferred_send_consumer_transactional_emails
      )
      expect(json_response).to have_key('mailer_logo_url')
    end

    it 'exposes the storefront-access gating defaults' do
      subject
      expect(json_response).to include(
        'preferred_storefront_access' => store.preferred_storefront_access,
        'preferred_guest_checkout' => store.preferred_guest_checkout
      )
    end

    context 'without authentication' do
      let(:headers) { {} }

      it 'returns unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH #update' do
    subject { patch :update, params: params, as: :json }

    context 'with valid params' do
      let(:params) { { name: 'Renamed Store' } }

      it 'updates the store and returns ok' do
        subject
        expect(response).to have_http_status(:ok)
        expect(store.reload.name).to eq('Renamed Store')
      end

      it 'returns the prefixed id in the response (not the raw DB id)' do
        subject
        expect(json_response['id']).to eq(store.prefixed_id)
        expect(json_response['id']).to start_with('store_')
      end

      it 'returns the storefront_url in the url field' do
        subject
        expect(json_response['url']).to eq(store.reload.storefront_url)
      end
    end

    context 'with invalid params' do
      let(:params) { { name: '' } }

      it 'returns a validation error' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
      end
    end

    context 'with order-numbering params' do
      let(:params) do
        {
          preferred_document_number_format: 'random',
          preferred_order_number_prefix: 'INV',
          preferred_order_number_suffix: '-EU',
          preferred_order_number_sequence_start: 5001
        }
      end

      it 'updates the numbering preferences' do
        subject
        expect(response).to have_http_status(:ok)
        store.reload
        expect(store.preferred_document_number_format).to eq('random')
        expect(store.preferred_order_number_prefix).to eq('INV')
        expect(store.preferred_order_number_suffix).to eq('-EU')
        expect(store.preferred_order_number_sequence_start).to eq(5001)
      end

      it 'exposes them in the response' do
        subject
        expect(json_response['preferred_order_number_prefix']).to eq('INV')
      end

      it 'reports that numbering has not started yet' do
        subject
        expect(json_response['order_number_sequence_started']).to be(false)
      end

      context 'once the counter has issued a number' do
        before { Spree::NumberSequence.next_value(store: store, resource_type: 'order') }

        it 'reports the started flag' do
          # Prefix stays editable after numbering starts — only the start locks.
          patch :update, params: { preferred_order_number_prefix: 'INV' }, as: :json
          expect(response).to have_http_status(:ok)
          expect(json_response['order_number_sequence_started']).to be(true)
        end

        it 'rejects a changed starting value' do
          subject
          expect(response).to have_http_status(:unprocessable_content)
          expect(json_response['error']['details']).to have_key('preferred_order_number_sequence_start')
        end
      end
    end

    context 'with an unsupported numbering format' do
      let(:params) { { preferred_document_number_format: 'roman_numerals' } }

      it 'returns a validation error' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with a prefix containing unsupported characters' do
      let(:params) { { preferred_order_number_prefix: 'inv/2026' } }

      it 'returns a validation error' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with email-section params' do
      let(:params) do
        {
          mail_from_address: 'mailer@example.com',
          customer_support_email: 'support@example.com',
          new_order_notifications_email: 'ops@example.com',
          preferred_send_consumer_transactional_emails: false
        }
      end

      it 'updates the email preferences and addresses' do
        subject
        expect(response).to have_http_status(:ok)
        store.reload
        expect(store.mail_from_address).to eq('mailer@example.com')
        expect(store.customer_support_email).to eq('support@example.com')
        expect(store.new_order_notifications_email).to eq('ops@example.com')
        expect(store.preferred_send_consumer_transactional_emails).to eq(false)
      end
    end

    context 'with an invalid mail_from_address' do
      let(:params) { { mail_from_address: 'not-an-email' } }

      it 'returns a validation error' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
      end
    end

    context 'with storefront-access gating params' do
      let(:params) { { preferred_storefront_access: 'login_required', preferred_guest_checkout: false } }

      it 'updates the store-wide gating defaults' do
        subject
        expect(response).to have_http_status(:ok)
        store.reload
        expect(store.preferred_storefront_access).to eq('login_required')
        expect(store.preferred_guest_checkout).to eq(false)
      end
    end

    context 'with address params' do
      let(:params) { { preferred_company_field_enabled: true, preferred_address_requires_phone: true } }

      it 'updates the address settings' do
        subject
        expect(response).to have_http_status(:ok)
        store.reload
        expect(store.preferred_company_field_enabled).to eq(true)
        expect(store.preferred_address_requires_phone).to eq(true)
      end
    end

    context 'with commerce behavior params' do
      let(:params) do
        {
          preferred_capture_method: 'on_dispatch',
          preferred_track_inventory_levels: false,
          preferred_show_products_without_price: true
        }
      end

      it 'updates the store-scoped commerce settings' do
        subject
        expect(response).to have_http_status(:ok)
        store.reload
        expect(store.preferred_capture_method).to eq('on_dispatch')
        expect(store.preferred_track_inventory_levels).to eq(false)
        expect(store.preferred_show_products_without_price).to eq(true)
      end
    end

    # Existing API clients keep working for one release; the model maps the
    # old names onto capture_method.
    context 'with the deprecated capture params' do
      let(:params) { { preferred_auto_capture_on_dispatch: true } }

      it 'maps them onto the capture method' do
        subject
        expect(response).to have_http_status(:ok)
        expect(store.reload.preferred_capture_method).to eq('on_dispatch')
      end
    end

    context 'with an invalid storefront_access value' do
      let(:params) { { preferred_storefront_access: 'nonsense' } }

      it 'returns a validation error' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
      end
    end

    context 'without authentication' do
      let(:headers) { {} }
      let(:params) { { name: 'Renamed Store' } }

      it 'returns unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end

    # Regression: StoreController inherits from Admin::BaseController (the
    # non-resource branch). Its scope guard once ran before authenticate_admin!
    # resolved the API key, so it short-circuited on a nil key and every
    # API-key caller could rewrite store settings without write_settings.
    context 'authenticated with a secret API key' do
      include_context 'API v3 Admin'

      let(:secret_api_key) { create(:api_key, :secret, store: store, scopes: scopes) }
      let(:headers) { api_key_headers }
      let(:params) { { name: 'Renamed Store' } }

      context 'lacking the write_settings scope' do
        let(:scopes) { ['read_orders'] }

        it 'denies the write with the required scope' do
          subject
          expect(response).to have_http_status(:forbidden)
          expect(json_response['error']['details']['required_scope']).to eq('write_settings')
          expect(store.reload.name).not_to eq('Renamed Store')
        end
      end

      context 'carrying the write_settings scope' do
        let(:scopes) { ['write_settings'] }

        it 'allows the write' do
          subject
          expect(response).to have_http_status(:ok)
          expect(store.reload.name).to eq('Renamed Store')
        end
      end
    end
  end
end
