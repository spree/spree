require 'spec_helper'

describe Spree::Api::V2::Platform::PriceSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:resource) { create(:price) }
  let(:type) { :price }

  it do
    expect(subject).to(
      eq(
        data: {
          id: resource.id.to_s,
          type: type,
          attributes: {
            amount: resource.amount,
            currency: resource.currency,
            deleted_at: resource.deleted_at,
            created_at: resource.created_at,
            updated_at: resource.updated_at,
            compare_at_amount: resource.compare_at_amount,
            display_compare_at_price: resource.display_compare_at_price.to_s,
            display_amount: resource.display_amount.to_s,
            display_price: resource.display_price.to_s,
            display_compare_at_amount: resource.display_compare_at_amount.to_s,
            display_compare_at_price_including_vat_for: resource.display_compare_at_price_including_vat_for({}).to_s,
            display_price_including_vat_for: resource.display_price_including_vat_for({}).to_s
          }
        }
      )
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
