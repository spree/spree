require 'spec_helper'

describe Spree::Api::V2::Platform::PromotionSerializer do
  subject { described_class.new(resource, params: serializer_params).serializable_hash }
  include_context 'API v2 serializers params'

  let(:promotion_category) { create(:promotion_category) }
  let(:promotion_rule) { create(:promotion_rule) }
  let(:resource) { create(:promotion_with_item_adjustment, promotion_category: promotion_category, promotion_rules: [promotion_rule]) }

  it { expect(subject).to be_kind_of(Hash) }

  it do
    expect(subject).to eq(
      {
        data: {
          id: resource.id.to_s,
          type: :promotion,
          attributes: {
            description: resource.description,
            expires_at: resource.expires_at,
            starts_at: resource.starts_at,
            name: resource.name,
            type: resource.type,
            usage_limit: resource.usage_limit,
            match_policy: resource.match_policy,
            code: resource.code,
            advertise: resource.advertise,
            path: resource.path,
            public_metadata: {},
            private_metadata: {},
            created_at: resource.created_at,
            updated_at: resource.updated_at
          },
          relationships: {
            promotion_category: {
              data: {
                id: resource.promotion_category.id.to_s,
                type: :promotion_category
              },
            },
            promotion_rules: {
              data: [
                {
                  id: resource.promotion_rules.first.id.to_s,
                  type: :promotion_rule
                }
              ]
            },
            promotion_actions: {
              data: [
                {
                  id: resource.promotion_actions.first.id.to_s,
                  type: :promotion_action
                }
              ]
            },
            stores: {
              data: [
                {
                  id: resource.stores.first.id.to_s,
                  type: :store
                }
              ]
            }
          }
        }
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
