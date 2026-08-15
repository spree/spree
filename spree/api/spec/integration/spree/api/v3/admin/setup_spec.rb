# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Setup API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  path '/api/v3/admin/auth/setup' do
    get 'Check first-run setup availability' do
      tags 'Authentication'
      produces 'application/json'
      description <<~DESC
        Reports whether first-run setup is still available — true only while
        the installation has no admin user. Unauthenticated; the dashboard
        login page uses it to offer the setup screen.
      DESC

      response '200', 'setup status' do
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['setup_required']).to be(true)
        end
      end
    end

    post 'Complete first-run setup' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      description <<~DESC
        Creates the first admin account and adopts the seeded store, authorized
        by the one-time setup token printed at install time (rotate it with
        `bin/rails spree:setup:token`). Issues a JWT access token and a
        refresh-token cookie exactly like login. Returns 404 once any admin
        user exists — the flow is closed permanently after setup.
      DESC

      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[setup_token email password country_code],
        properties: {
          setup_token: { type: :string, description: 'One-time token from the install output.' },
          email: { type: :string, format: 'email', example: 'owner@example.com' },
          password: { type: :string, example: 'Secret123!' },
          password_confirmation: { type: :string, example: 'Secret123!' },
          first_name: { type: :string, example: 'Olivia' },
          last_name: { type: :string, example: 'Owner' },
          store_name: { type: :string, example: 'My Store' },
          country_code: {
            type: :string,
            description: 'ISO 3166-1 alpha-2 country the store sells from. Determines the ' \
                         'default market, the warehouse, the delivery zones and the currency.',
            example: 'US'
          },
          locale: {
            type: :string,
            description: "Storefront locale. Defaults to the country's own language.",
            example: 'en'
          },
          currency: {
            type: :string,
            description: "ISO 4217 currency. Defaults to the country's own currency — " \
                         'pass one only when the store prices in something else.',
            example: 'USD'
          }
        }
      }

      response '200', 'setup completed' do
        let(:body) do
          {
            setup_token: Spree::Store.default.setup_token,
            email: 'owner@example.com',
            password: 'Secret123!',
            password_confirmation: 'Secret123!',
            first_name: 'Olivia',
            last_name: 'Owner',
            store_name: 'My Store',
            country_code: 'US'
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']['email']).to eq('owner@example.com')
        end
      end

      response '404', 'setup not available' do
        let(:body) do
          {
            setup_token: 'wrong-token',
            email: 'owner@example.com',
            password: 'Secret123!',
            store_name: 'My Store',
            country_code: 'US'
          }
        end

        run_test!
      end
    end
  end

  path '/api/v3/admin/auth/setup/countries' do
    get 'List countries for first-run setup' do
      tags 'Authentication'
      produces 'application/json'
      description <<~DESC
        Countries the store can be set up in, each with the currency and
        official languages derived from it. Unauthenticated, because the setup
        screen runs before any credential exists. Returns 404 once any admin
        user exists.
      DESC

      response '200', 'countries' do
        run_test! do |response|
          data = JSON.parse(response.body)
          switzerland = data['countries'].find { |country| country['code'] == 'CH' }

          expect(switzerland['currency']).to eq('CHF')
          expect(switzerland['locales']).to include('de')
        end
      end
    end
  end
end
