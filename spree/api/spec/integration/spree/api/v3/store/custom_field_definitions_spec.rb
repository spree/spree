# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Custom Field Definitions API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:delivery_date) do
    create(:custom_field_definition, :for_order, :date_field, store: store, namespace: 'checkout', label: 'Delivery date',
                                                              storefront_writable: true, validations: { required: true })
  end
  let!(:gender) do
    create(:custom_field_definition, :for_user, :choice_field, store: store, namespace: 'profile', key: 'gender', label: 'Gender',
                                                               storefront_writable: true)
  end

  path '/api/v3/store/custom_field_definitions' do
    get 'List the custom fields shoppers fill in' do
      tags 'Custom Fields'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Returns the custom fields a shopper fills in, with each field's type, label and rules, so a storefront
        can render the form and check values before sending them. Filter by `q[resource_type_eq]=order` for
        the fields asked at checkout (written on the cart), or `customer` for the fields asked at registration
        and in the account. Write values by `full_key` in `custom_fields` on the cart or customer. Fields the
        merchant keeps admin-only, or only shows on the storefront, are never listed.
      DESC

      sdk_example 'custom-field-definitions/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      filter_parameters_for

      response '200', 'custom fields listed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:q) { { resource_type_eq: 'order' } }

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.pluck('full_key')).to eq(['checkout.delivery_date'])
        end
      end
    end
  end
end
