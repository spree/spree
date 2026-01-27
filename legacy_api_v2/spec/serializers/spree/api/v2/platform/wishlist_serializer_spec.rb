require 'spec_helper'

describe Spree::Api::V2::Platform::WishlistSerializer do
  subject { described_class.new(wishlist) }

  let!(:user) { create(:user) }
  let!(:wishlist) { create(:wishlist, user: user) }
  let!(:wished_item) { create(:wished_item, wishlist: wishlist) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: wishlist.id.to_s,
          type: :wishlist,
          attributes: {
            name: wishlist.name,
            is_default: false,
            is_private: true,
            token: wishlist.token,
            variant_included: false,
            created_at: wishlist.created_at,
            updated_at: wishlist.updated_at
          },
          relationships: {
            wished_items: {
              data: [
                {
                  id: wishlist.wished_items.first.id.to_s,
                  type: :wished_item
                }
              ]
            }
          }
        }
      }
    )
  end
end
