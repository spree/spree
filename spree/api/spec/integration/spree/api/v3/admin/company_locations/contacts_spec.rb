# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Company Contacts API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:company) { create(:company, store: store) }
  let!(:location) { create(:company_location, company: company, name: 'Berlin') }
  let!(:customer) { create(:customer, email: 'buyer@acme.test') }
  let!(:contact) { create(:company_contact, company_location: location, customer: customer) }

  path '/api/v3/admin/company_locations/{company_location_id}/contacts' do
    let(:company_location_id) { location.prefixed_id }
    let(:'x-spree-api-key') { secret_api_key.plaintext_token }

    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :company_location_id, in: :path, type: :string, required: true

    get 'List company contacts' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the customers authorised to purchase for a branch. A customer may act for more than one branch.'
      admin_scope :read, :customers

      admin_sdk_example 'company-locations/contacts-list'

      response '200', 'contacts found' do
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('id')).to include(contact.prefixed_id)
        end
      end
    end

    post 'Create a company contact' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Authorises a customer to purchase for a branch. A customer who acts for exactly one branch has
        their orders attributed to it automatically; one who acts for several needs the branch set on
        the order, because guessing would invoice the wrong business.
      DESC
      admin_scope :write, :customers

      admin_sdk_example 'company-locations/contacts-create'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          customer_id: { type: :string, example: 'cus_UkLWZg9DAJ' },
          role: { type: :string, description: 'Free-form label; carries no permissions in 6.0.', example: 'buyer' }
        },
        required: ['customer_id']
      }

      response '201', 'contact created' do
        let(:body) { { customer_id: create(:customer).prefixed_id, role: 'admin' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['role']).to eq('admin')
        end
      end

      response '422', 'invalid request' do
        # The same customer cannot be added to one branch twice.
        let(:body) { { customer_id: customer.prefixed_id } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/company_contacts/{id}' do
    let(:id) { contact.prefixed_id }
    let(:'x-spree-api-key') { secret_api_key.plaintext_token }

    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true

    get 'Get a company contact' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :customers

      admin_sdk_example 'company-contacts/get'

      response '200', 'contact found' do
        run_test! do |response|
          expect(JSON.parse(response.body)['email']).to eq('buyer@acme.test')
        end
      end
    end

    delete 'Delete a company contact' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Withdraws the customer\'s authority to purchase for the branch. The customer account itself is untouched.'
      admin_scope :write, :customers

      admin_sdk_example 'company-contacts/delete'

      response '204', 'contact deleted' do
        run_test!
      end
    end
  end
end
