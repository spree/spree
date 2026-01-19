# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::WishlistSerializer do
  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:wishlist) do
    create(:wishlist,
           user: user,
           store: store,
           name: 'My Wishlist',
           is_private: true,
           is_default: false)
  end

  subject { described_class.serialize(wishlist) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(wishlist.id)
      expect(subject[:name]).to eq('My Wishlist')
    end

    it 'includes privacy settings' do
      expect(subject[:is_private]).to eq(true)
      expect(subject[:is_default]).to eq(false)
    end

    it 'includes foreign keys' do
      expect(subject[:user_id]).to eq(user.id)
      expect(subject[:store_id]).to eq(store.id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end

    it 'does not include token' do
      expect(subject).not_to have_key(:token)
    end
  end
end
