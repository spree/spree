# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Tax Identifiers API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end
  let(:vat_number) { eu_vat_number(0) }

  path '/api/v3/seller/tax_identifiers' do
    get 'List tax registrations' do
      tags 'Tax Identifiers'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The seller's own registrations — the numbers the marketplace's
        commission invoice is made out to, and what makes EU reverse charge on
        that fee possible.

        A collection rather than a single field: a business trading in more
        than one regime holds a registration in each, and they are not
        alternatives. One per kind.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'registrations returned' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        before { seller.tax_identifiers.create!(kind: 'eu_vat', value: vat_number) }

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].first['value']).to eq(vat_number)
        end
      end
    end

    post 'Add a tax registration' do
      tags 'Tax Identifiers'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        `kind` names the regime — `eu_vat`, `gb_vat`, and whatever else a
        validator is registered for. Any string is accepted; what a kind means
        is decided by its validator, and a kind nothing is registered for is
        stored and used as entered.

        A number a registered validator refuses is rejected outright rather
        than stored, so a typo cannot reach an invoice.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          kind: { type: :string, example: 'eu_vat' },
          value: { type: :string, example: 'DE100000008' }
        },
        required: %w[kind value]
      }

      response '201', 'registration recorded' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { kind: 'eu_vat', value: vat_number } }

        run_test!
      end

      response '422', 'the number is not valid for its regime' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { kind: 'eu_vat', value: 'DE123' } }

        run_test!
      end
    end
  end

  path '/api/v3/seller/tax_identifiers/{id}' do
    parameter name: :id, in: :path, type: :string

    patch 'Correct a tax registration' do
      tags 'Tax Identifiers'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        A changed number drops its validation verdict, because that answer was
        about the old one.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          kind: { type: :string, example: 'eu_vat' },
          value: { type: :string, example: 'DE100000016' }
        }
      }

      response '200', 'registration corrected' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { seller.tax_identifiers.create!(kind: 'eu_vat', value: vat_number).prefixed_id }
        let(:body) { { value: eu_vat_number(1) } }

        run_test!
      end
    end

    delete 'Remove a tax registration' do
      tags 'Tax Identifiers'
      security [bearer_auth: []]

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '204', 'registration removed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { seller.tax_identifiers.create!(kind: 'eu_vat', value: vat_number).prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/seller/tax_identifiers/{id}/validate' do
    parameter name: :id, in: :path, type: :string

    post 'Re-check a registration against its registry' do
      tags 'Tax Identifiers'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        A registry answers "valid now", so a number verified last year may have
        been deregistered since. Refused when no registry validator is
        installed for the kind — core format-checks EU VAT numbers but asks no
        registry, so a stock install answers 422 here rather than queueing a
        check nobody can answer.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '422', 'no registry validator is installed for this kind' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { seller.tax_identifiers.create!(kind: 'eu_vat', value: vat_number).prefixed_id }

        run_test!
      end
    end
  end
end
