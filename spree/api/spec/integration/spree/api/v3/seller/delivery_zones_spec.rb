# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Delivery Zones API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let(:seller_role) { create(:role, name: 'Seller', resource: seller, permissions: %w[read_delivery_methods]) }

  let!(:delivery_profile) { create(:delivery_profile, store: store, name: 'Parcel') }
  let!(:delivery_zone) do
    create(:delivery_zone, store: store, delivery_profile: delivery_profile, name: 'Domestic')
  end

  path '/api/v3/seller/delivery_zones' do
    get 'List delivery zones' do
      tags 'Delivery Zones'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The marketplace's delivery zones — where its methods may ship to.

        Read only: a seller narrows their own method to one of these and never
        draws one. Pass `delivery_profile_id` to list only the zones under the
        profile a method belongs to, which is what the method form's picker
        asks for.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :delivery_profile_id, in: :query, type: :string, required: false,
                description: 'Only zones under this delivery profile'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'

      response '200', 'delivery zones listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/DeliveryZone' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to include(delivery_zone.prefixed_id)
        end
      end
    end
  end
end
