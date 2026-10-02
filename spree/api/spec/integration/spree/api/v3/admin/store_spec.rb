# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Store API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  let(:store) { @default_store }
  let!(:market) { create(:market, store: store) }

  # Reload to drop any in-memory mutations left over from earlier rolled-back
  # examples (the shared `@default_store` AR instance survives the suite).
  before { store.reload }

  path '/api/v3/admin/store' do
    get 'Get the current store' do
      tags 'Settings'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the current store configuration. The store is resolved from the request context (host or admin selection); there is no `id` parameter.'
      admin_scope :read, :settings

      admin_sdk_example 'store/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'current store' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema '$ref' => '#/components/schemas/Store'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(store.prefixed_id)
          expect(data['id']).to start_with('store_')
          expect(data['name']).to eq(store.name)
          expect(data['url']).to eq(store.storefront_url)
          expect(data['default_country_code']).to eq(store.default_country_code)
          expect(data['setup_tasks'].map { |t| t['name'] }).to eq(
            %w[setup_address setup_payment_method add_products set_customer_support_email setup_taxes_collection
               setup_storefront]
          )
          expect(data['setup_tasks']).to all(match('name' => be_a(String), 'done' => be_in([true, false])))
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update the current store' do
      tags 'Settings'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates the current store configuration.'
      admin_scope :write, :settings

      admin_sdk_example 'store/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'My Store' },
          mail_from_address: { type: :string, example: 'no-reply@example.com' },
          customer_support_email: { type: :string, nullable: true, example: 'support@example.com' },
          new_order_notifications_email: { type: :string, nullable: true, example: 'orders@example.com' },
          preferred_admin_locale: { type: :string, nullable: true, example: 'en' },
          preferred_timezone: { type: :string, example: 'UTC' },
          preferred_weight_unit: { type: :string, example: 'kg' },
          preferred_unit_system: { type: :string, example: 'metric' },
          preferred_storefront_access: { type: :string, enum: %w[public prices_hidden login_required] },
          preferred_storefront_url: { type: :string, nullable: true },
          preferred_guest_checkout: { type: :boolean },
          preferred_always_include_confirm_step: { type: :boolean },
          preferred_company_field_enabled: { type: :boolean },
          preferred_address_requires_company: { type: :boolean },
          preferred_address_requires_phone: { type: :boolean },
          preferred_capture_method: { type: :string, enum: %w[checkout on_dispatch manual] },
          preferred_auto_capture: { type: :boolean, deprecated: true, description: 'Superseded by `preferred_capture_method`.' },
          preferred_auto_capture_on_dispatch: { type: :boolean },
          preferred_track_inventory_levels: { type: :boolean },
          preferred_stock_reservations_enabled: { type: :boolean },
          preferred_low_stock_threshold: { type: :integer },
          preferred_tax_using_ship_address: { type: :boolean },
          preferred_track_price_history: { type: :boolean },
          preferred_show_products_without_price: { type: :boolean },
          preferred_disable_sku_validation: { type: :boolean },
          preferred_order_routing_strategy: { type: :string },
          preferred_pricing_provider: { type: :string },
          preferred_inventory_provider: { type: :string },
          preferred_pricing_provider_failure_policy: { type: :string, enum: %w[fallback strict] },
          preferred_inventory_provider_failure_policy: { type: :string, enum: %w[fallback strict] },
          preferred_payout_provider: { type: :string, nullable: true },
          preferred_default_payouts_schedule_interval: { type: :string, enum: %w[daily weekly biweekly monthly manual] },
          preferred_default_minimum_payout_amount: { type: :number },
          preferred_auto_approve_sellers: { type: :boolean },
          preferred_auto_approve_seller_products: { type: :boolean },
          preferred_send_seller_transactional_emails: { type: :boolean },
          preferred_send_consumer_transactional_emails: { type: :boolean },
          preferred_default_commission_tax_rate: { type: :number },
          preferred_document_number_format: { type: :string, enum: %w[sequential random] },
          preferred_order_number_prefix: { type: :string },
          preferred_order_number_suffix: { type: :string },
          preferred_order_number_sequence_start: { type: :integer },
          mailer_logo: { type: :string, description: 'Signed blob id of an uploaded logo.' }
        }
      }

      response '200', 'store updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Renamed Store' } }

        schema '$ref' => '#/components/schemas/Store'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Renamed Store')
          expect(data['id']).to eq(store.prefixed_id)
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
