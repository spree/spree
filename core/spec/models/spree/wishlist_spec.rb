require 'spec_helper'

describe Spree::Wishlist, type: :model do
  let!(:store) { Spree::Store.default }
  let!(:other_store) { create(:store) }
  let!(:user) { create(:user) }
  let!(:other_user) { create(:user) }

  let!(:wishlist) { create(:wishlist, user: user, name: 'My Wishlist', store: store, is_default: true) }
  let!(:wishlist_belonging_to_other_store) { create(:wishlist, user: user, name: 'My Wishlist', store: other_store, is_default: true) }
  let!(:wishlist_belonging_to_other_user) { create(:wishlist, user: other_user, name: 'My Wishlist', store: store, is_default: true) }

  it 'has a valid factory' do
    expect(wishlist).to be_valid
  end

  it 'validates presence of name' do
    expect(described_class.new(name: nil, user: user, store: store)).not_to be_valid
  end

  it 'validates presence of store' do
    expect(described_class.new(name: 'My Wishlist', user: user, store: nil)).not_to be_valid
  end

  it 'validates presence of user' do
    expect(described_class.new(name: 'My Wishlist', user: nil, store: store)).not_to be_valid
  end

  describe '.ensure_default_exists_and_is_unique' do
    context 'when user creates a new default store' do
      let!(:new_wl) { create(:wishlist, name: 'My New WishList', user: user, store: store, is_default: true) }

      it 'preserves is_default: true for new wishlist' do
        expect(new_wl.is_default).to be true
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
      wished_item = create(:wished_item, variant: variant)
      wishlist.wished_items << wished_item
      wishlist.save
    end

    it 'is true if the wishlist includes the specified variant' do
      expect(wishlist.include?(variant.id)).to be true
    end
  end

  describe '.to_param' do
    it 'returns the wishlists token' do
      expect(wishlist.to_param).to eq wishlist.token
    end
  end

  describe '.get_by_param' do
    it 'returns the wishlist of the token' do
      hash = wishlist.token
      result = described_class.get_by_param(hash)
      expect(result).to eq wishlist
    end

    it 'returns nil when not found' do
      result = described_class.get_by_param('nope')
      expect(result).to be_nil
    end
  end

  describe '#destroy' do
    let!(:wished_item) { create(:wished_item) }

    it 'deletes associated wished variants' do
      expect do
        wished_item.wishlist.destroy
      end.to change(Spree::WishedItem, :count).by(-1)
    end
  end
end
