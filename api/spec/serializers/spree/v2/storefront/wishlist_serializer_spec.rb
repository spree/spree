require 'spec_helper'

describe Spree::V2::Storefront::WishlistSerializer do
  subject { described_class.new(wishlist) }

  let!(:wishlist) { create(:wishlist) }
  let!(:wished_item) { create(:wished_item, wishlist: wishlist, variant: create(:variant), quantity: 1) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: wishlist.id.to_s,
          type: :wishlist,
          attributes: {
            name: wishlist.name,
            token: wishlist.token,
            is_private: wishlist.is_private,
            is_default: wishlist.is_default
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
