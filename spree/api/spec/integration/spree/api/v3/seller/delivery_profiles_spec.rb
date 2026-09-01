# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Delivery Profiles API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let!(:delivery_profile) { create(:delivery_profile, store: store, name: 'Oversized') }

  path '/api/v3/seller/delivery_profiles' do
    get 'List delivery profiles' do
      tags 'Delivery Profiles'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The marketplace's delivery profiles — what kind of goods a product is
        (parcel, digital, pallet), which decides how it can be shipped.

        Read only. A seller assigns one to a product as `delivery_profile_id`;
        the profiles themselves, and the zones and methods behind them, are the
        marketplace's. A product created without one lands on the profile
        marked `default`.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'

      response '200', 'delivery profiles listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/DeliveryProfile' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to include(delivery_profile.prefixed_id)
        end
      end
    end
  end
end
