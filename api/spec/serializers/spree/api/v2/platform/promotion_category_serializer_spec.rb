require 'spec_helper'

describe Spree::Api::V2::Platform::PromotionCategorySerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params) }

  let(:resource) { create(:promotion_category, name: '2021 Promotions', code: '2021-PROMOS') }
  let!(:promtion_a) { create(:promotion, promotion_category: resource)}
  let!(:promtion_b) { create(:promotion, promotion_category: resource)}

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: resource.id.to_s,
          type: :promotion_category,
          attributes: {
            name: resource.name,
            code: resource.code,
            created_at: resource.created_at,
            updated_at: resource.updated_at
          },
          relationships: {
            promotions: {
              data: [
                {
                  id: resource.promotions.first.id.to_s,
                  type: :promotion
                },
                {
                  id: resource.promotions.second.id.to_s,
                  type: :promotion
                }
              ]
            }
          }
        }
      }
    )
  end
end
