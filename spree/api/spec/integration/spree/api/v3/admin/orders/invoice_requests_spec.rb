# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Invoice Requests API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let!(:invoice_request) { create(:invoice_request, order: order) }

  path '/api/v3/admin/orders/{order_id}/invoice_requests' do
    parameter name: :order_id, in: :path, type: :string, required: true

    get "List the buyer's invoice requests" do
      tags 'Invoices'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'What the buyer asked an invoice to say. An open request is fulfilled by adding an invoice of kind `invoice` to the order.'
      admin_scope :read, :orders
      admin_sdk_example 'order-invoice-requests/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      filter_parameters_for

      response '200', 'requests found' do
        let(:order_id) { order.prefixed_id }

        schema SwaggerSchemaHelpers.paginated('InvoiceRequest')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].first).to include('status' => 'open', 'company_name' => 'Acme GmbH')
        end
      end
    end
  end
end
