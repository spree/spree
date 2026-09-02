# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Customer Privacy API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:customer) { create(:user, email: 'jane@example.com', first_name: 'Jane', last_name: 'Doe') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/customers/{id}/export' do
    get 'Export a customer\'s personal data' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns everything the store holds about this customer, for answering a
        GDPR right-of-access request (Art. 15) that reached the merchant
        directly.
      DESC
      admin_scope :read, :customers

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'customer data' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { customer.prefixed_id }

        schema type: :object,
               properties: {
                 account: { type: :object },
                 marketing_consent: { type: :object },
                 consent_records: { type: :array, items: { type: :object } },
                 addresses: { type: :array, items: { type: :object } },
                 orders: { type: :array, items: { type: :object } },
                 exported_at: { type: :string }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['account']['email']).to eq('jane@example.com')
        end
      end

      response '404', 'not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'cust_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/customers/{id}/anonymize' do
    post 'Erase a customer\'s personal data' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Carries out a GDPR right-to-erasure request (Art. 17). Personal data is
        replaced across the account, its addresses, the address snapshots on
        past orders, saved cards, connected identities and live sessions.

        Orders, payments and tax records are kept — they carry their own
        retention obligation — with the personal details removed. The country,
        state and a truncated postal code survive on order addresses so the tax
        jurisdiction of a past sale stays provable.

        Irreversible.
      DESC
      admin_scope :write, :customers

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'customer anonymized' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { customer.prefixed_id }

        schema type: :object, properties: {
          id: { type: :string },
          email: { type: :string },
          anonymized: { type: :boolean },
          anonymized_at: { type: :string, nullable: true }
        }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['anonymized']).to be(true)
        end
      end

      response '422', 'already anonymized' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { customer.prefixed_id }

        before { Spree::Customers::Anonymize.call(customer: customer, store: store) }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
