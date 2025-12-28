# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::WishedItemSerializer do
  let(:user) { create(:user) }
  let(:wishlist) { create(:wishlist, user: user) }
  let(:variant) { create(:variant) }
  let(:wished_item) { create(:wished_item, wishlist: wishlist, variant: variant, quantity: 2) }

  subject { described_class.serialize(wished_item) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(wished_item.id)
    end

    it 'includes quantity' do
      expect(subject[:quantity]).to eq(2)
    end

    it 'includes foreign keys' do
      expect(subject[:variant_id]).to eq(variant.id)
      expect(subject[:wishlist_id]).to eq(wishlist.id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
