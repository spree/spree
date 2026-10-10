require 'spec_helper'

describe Spree::Wishlist, type: :model do
  let(:store) { @default_store }
  let(:other_store) { create(:store) }
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  let(:wishlist) { create(:wishlist, customer: user, name: 'My Wishlist', store: store, is_default: true) }
  let(:wishlist_belonging_to_other_store) { create(:wishlist, customer: user, name: 'My Wishlist', store: other_store, is_default: true) }
  let(:wishlist_belonging_to_other_user) { create(:wishlist, customer: other_user, name: 'My Wishlist', store: store, is_default: true) }

  it_behaves_like 'lifecycle events'

  describe '.ensure_default_exists_and_is_unique' do
    context 'when user creates a new default store' do
      let(:new_wl) { create(:wishlist, name: 'My New WishList', customer: user, store: store, is_default: true) }

      before do
        wishlist
        new_wl
      end

      it 'preserves is_default: true for new wishlist' do
        expect(new_wl.reload.is_default).to be true
      end

      it 'sets is_default: false on the wishlist that was the previous default' do
        wishlist.reload

        expect(wishlist.is_default).to be false
      end

      it 'does not alter the state of wishlist belonging to other users' do
        wishlist_belonging_to_other_user.reload

        expect(wishlist_belonging_to_other_user.is_default).to be true
      end

      it 'does not alter the state of wishlist belonging to same users, but in other stores' do
        wishlist_belonging_to_other_store.reload

        expect(wishlist_belonging_to_other_store.is_default).to be true
      end
    end
  end

  describe '.include?' do
    let(:variant) { create(:variant) }

    before do
      wishlist_item = create(:wishlist_item, variant: variant)
      wishlist.wishlist_items << wishlist_item
      wishlist.save
    end

    it 'is true if the wishlist includes the specified variant' do
      expect(wishlist.include?(variant.id)).to be true
    end
  end

  describe '#product_ids' do
    let(:product) { create(:product) }
    let(:variant) { create(:variant, product: product) }
    let(:variant_2) { create(:variant, product: product) }

    before do
      wishlist.wishlist_items << create(:wishlist_item, variant: variant)
      wishlist.wishlist_items << create(:wishlist_item, variant: variant_2)
    end

    it 'returns the product ids' do
      expect(wishlist.product_ids).to eq [product.id]
    end
  end

  describe '#wished_items_count' do
    # The pre-6.0 name stays callable for one release.
    it 'delegates to the renamed counter' do
      wishlist = create(:wishlist)
      create(:wishlist_item, wishlist: wishlist)
      expect(Spree::Deprecation).to receive(:warn).with(/wished_items_count/)

      expect(wishlist.wished_items_count).to eq(1)
    end
  end

end
