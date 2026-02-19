# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Digitals API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:product) { create(:product, stores: [store]) }
  let(:order) { create(:order_with_line_items, store: store, user: user, line_items_attributes: [{ variant: product.master, quantity: 1 }]) }
  let(:line_item) { order.line_items.first }
  let(:digital) { create(:digital, variant: line_item.variant) }
  let!(:digital_link) { create(:digital_link, digital: digital, line_item: line_item) }

  path '/api/v3/store/digitals/{token}' do
    get 'Download a digital product' do
      tags 'Digitals'
      produces 'application/octet-stream', 'application/json'
      description <<~DESC
        Downloads a digital product file using the digital link token.
        The token is provided via the `download_url` field on digital links
        returned with order line items. No API key or authentication required —
        the token itself grants access.
        Each download increments the access counter. Downloads may be limited by
        store settings (number of downloads and/or time-based expiration).
      DESC

      parameter name: :token, in: :path, type: :string, required: true,
                description: 'Digital link token'

      response '200', 'file downloaded' do
        let(:token) { digital_link.token }

        run_test! do |response|
          expect(response.headers['Content-Disposition']).to include('thinking-cat.jpg')
          expect(digital_link.reload.access_counter).to eq(1)
        end
      end

      response '403', 'download link expired or limit exceeded' do
        let(:token) { digital_link.token }

        before do
          store.update!(
            preferred_limit_digital_download_count: true,
            preferred_digital_asset_authorized_clicks: 1
          )
          digital_link.update_column(:access_counter, 1)
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('digital_link_expired')
        end
      end

      response '404', 'digital link not found' do
        let(:token) { 'invalid_token' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
