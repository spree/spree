require 'spec_helper'

describe Spree::Api::V2::Platform::WishedItemSerializer do
  subject { described_class.new(wished_item, params: serializer_params) }

  include_context 'API v2 serializers params'

  let!(:user) { create(:user) }
  let!(:variant) { create(:variant) }
  let!(:wishlist) { create(:wishlist, user: user) }
  let!(:wished_item) { create(:wished_item, wishlist: wishlist, variant: variant, quantity: 3) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: wished_item.id.to_s,
          type: :wished_item,
          attributes: {
            quantity: 3,
            price: variant.price,
            total: variant.price * 3,
            display_price: '$19.99',
            display_total: '$59.97',
            created_at: wished_item.created_at,
            updated_at: wished_item.updated_at
          },
          relationships: {
            variant: {
              data:
                {
                  id: variant.id.to_s,
                  type: :variant
                }
            }
          }
        }
      }
    )
  end
end
