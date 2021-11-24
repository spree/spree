require 'spec_helper'

describe Spree::V2::Storefront::WishedItemSerializer do
  subject { described_class.new(wished_item, params: { currency: 'USD' }).serializable_hash }

  let!(:wishlist) { create(:wishlist) }
  let!(:wished_item) { create(:wished_item, wishlist: wishlist, variant: create(:variant), quantity: 5) }

  it { expect(subject).to be_kind_of(Hash) }

  it do
    expect(subject).to eq(
      {
        data: {
          id: wished_item.id.to_s,
          type: :wished_item,
          attributes: {
            display_price: '$19.99',
            display_total: '$99.95',
            price: wished_item.variant.price,
            total: (wished_item.variant.price * 5),
            quantity: 5,
          },
          relationships: {
            variant: {
              data: {
                id: wished_item.variant.id.to_s,
                type: :variant
              }
            }
          }
        }
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
