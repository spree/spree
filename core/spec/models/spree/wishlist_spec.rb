require 'spec_helper'

describe Spree::Wishlist, type: :model do
  let(:user) { create(:user) }
  let(:wishlist) { create(:wishlist, user: user, name: 'My Wishlist') }

  it 'has a valid factory' do
    expect(wishlist).to be_valid
  end

  context '.include?' do
    let(:variant) { create(:variant) }

    before do
      wished_variant = create(:wished_variant, variant: variant)
      wishlist.wished_variants << wished_variant
      wishlist.save
    end

    it 'is true if the wishlist includes the specified variant' do
      expect(wishlist.include?(variant.id)).to be true
    end
  end

  context '.to_param' do
    it 'returns the wishlists token' do
      expect(wishlist.to_param).to eq wishlist.token
    end
  end

  context '.get_by_param' do
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

  context '.can_be_read_by?' do
    context 'when the wishlist is private' do
      it 'is true when the user owns the wishlist' do
        wishlist.is_private = true
        expect(wishlist.can_be_read_by?(user)).to be true
      end

      it 'is false when the user does not own the wishlist' do
        wishlist.is_private = true
        other_user = create(:user)
        expect(wishlist.can_be_read_by?(other_user)).to be false
      end
    end

    context 'when the wishlist is public' do
      it 'is true for any user' do
        wishlist.is_private = false
        other_user = create(:user)
        expect(wishlist.can_be_read_by?(other_user)).to be true
      end
    end
  end

  context '.public?' do
    it 'is true when the wishlist is public' do
      wishlist.is_private = false
      expect(wishlist.public?).to be true
    end

    it 'is false when the wishlist is private' do
      wishlist.is_private = true
      expect(wishlist.public?).not_to be true
    end
  end

  context '#destroy' do
    let!(:wished_variant) { create(:wished_variant) }

    it 'deletes associated wished products' do
      expect {
        wished_variant.wishlist.destroy
      }.to change(Spree::WishedVariant, :count).by(-1)
    end
  end
end
