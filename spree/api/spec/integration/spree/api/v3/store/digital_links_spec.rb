# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Digital Links API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:product) { create(:product) }
  let(:order) { create(:order_with_line_items, store: store, customer: user, line_items_attributes: [{ variant: product.default_variant, quantity: 1 }]) }
  let(:line_item) { order.line_items.first }
  let(:digital_asset) { create(:digital_asset, variant: line_item.variant) }
  let!(:digital_link) { create(:digital_link, digital_asset: digital_asset, line_item: line_item) }

  path '/api/v3/store/digital_links/{token}' do
    get 'Download a digital product' do
      tags 'Digital Links'
      produces 'application/json'
      description <<~DESC
        Downloads a digital product file using the digital link token.
        The token is provided via the `download_url` field on digital links
        returned with order line items. No API key or authentication required —
        the token itself grants access.

        Responds with a redirect to a short-lived download URL; follow it to
        fetch the file. Each download increments the access counter. Downloads
        may be limited by the asset's own settings, falling back to the store's
        (number of downloads and/or time-based expiration).
      DESC

      parameter name: :token, in: :path, type: :string, required: true,
                description: 'Digital link token'

      response '302', 'redirect to the file download' do
        let(:token) { digital_link.token }

        run_test! do |response|
          expect(response.headers['Location']).to be_present
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
