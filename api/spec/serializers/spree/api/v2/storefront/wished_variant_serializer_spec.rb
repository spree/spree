require 'spec_helper'

describe Spree::V2::Storefront::WishedVariantSerializer do
  subject { described_class.new(wished_variant, params: { currency: 'USD' }) }

  let!(:wishlist) { create(:wishlist) }
  let!(:wished_variant) { create(:wished_variant, wishlist: wishlist, variant: create(:variant), quantity: 5 ) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: wished_variant.id.to_s,
          type: :wished_variant,
          attributes: {
            display_price: '$19.99',
            display_total: '$99.95',
            price: wished_variant.variant.price,
            total: (wished_variant.variant.price * 5),
            quantity: 5,
          },
          relationships: {
            variant: {
              data: {
                id: wished_variant.variant.id.to_s,
                type: :variant
              }
            },
            wishlist: {
              data: {
                id: wishlist.id.to_s,
                type: :wishlist
              }
            }
          }
        }
      }
    )
  end
end
