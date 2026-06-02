# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Coupon Codes API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:promotion) do
    create(:promotion, kind: :coupon_code, code: 'SUMMER')
  end
  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:promotion_id) { promotion.prefixed_id }

  path '/api/v3/admin/promotions/{promotion_id}/coupon_codes' do
    parameter name: :promotion_id, in: :path, type: :string, required: true

    get 'List coupon codes for a promotion' do
      tags 'Promotions'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the auto-generated coupon codes for a multi-code promotion. Single-code promotions store the code on the promotion itself; this endpoint returns an empty list for them.'
      admin_scope :read, :promotions

      admin_sdk_example 'coupon-codes/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'coupon codes found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        before do
          Spree::CouponCode.create!(promotion: promotion, code: 'AAA111', state: 'unused')
          Spree::CouponCode.create!(promotion: promotion, code: 'BBB222', state: 'unused')
        end

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.size).to eq(2)
          expect(data.map { |c| c['code'] }).to contain_exactly('AAA111', 'BBB222')
        end
      end
    end
  end
end
