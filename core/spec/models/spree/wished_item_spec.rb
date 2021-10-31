require 'spec_helper'

RSpec.describe Spree::WishedItem, type: :model do
  describe '.quantity' do
    subject { build(:wished_item) }

    let!(:wishlist) { create(:wishlist) }
    let!(:variant) { create(:variant) }
    let!(:wished_item_with_variant) { create(:wished_item, variant: variant, quantity: 3) }

    it { is_expected.to respond_to(:quantity) }
    it { expect(subject.quantity).to eq(1) }

    it 'validates presence of wishlist' do
      expect(described_class.new(quantity: 3, wishlist: nil, variant: variant)).not_to be_valid
    end

    it 'validates presence of variant' do
      expect(described_class.new(quantity: 3, wishlist: wishlist, variant: nil)).not_to be_valid
    end

    it 'validates numericality of quantity' do
      expect(described_class.new(quantity: nil, wishlist: wishlist, variant: variant)).not_to be_valid
      expect(described_class.new(quantity: 'string', wishlist: wishlist, variant: variant)).not_to be_valid
      expect(described_class.new(quantity: 0.5, wishlist: wishlist, variant: variant)).not_to be_valid
    end

    it 'validates numericality must be greater than 0' do
      expect(described_class.new(quantity: 0, wishlist: wishlist, variant: variant)).not_to be_valid
      expect(described_class.new(quantity: -1, wishlist: wishlist, variant: variant)).not_to be_valid
    end

    describe 'when wished_item is already associated with the wishlist' do
      let!(:existing_wished_item) { create(:wished_item, quantity: 3, wishlist: wishlist, variant: variant) }

      it 'validates uniqueness of variant within scope of wishlist' do
        expect(described_class.new(quantity: 2, wishlist: wishlist, variant: variant)).not_to be_valid
      end
    end

    describe '.price' do
      it { expect(wished_item_with_variant.price(currency: 'USD')).to eq(variant.amount_in('USD')) }
    end

    describe '.total' do
      it { expect(wished_item_with_variant.total(currency: 'USD')).to eql(variant.amount_in('USD') * 3) }
    end

    describe '.display_price' do
      it { expect(wished_item_with_variant.display_price(currency: 'USD')).to eq Spree::Money.new(variant.amount_in('USD'), currency: 'USD') }
    end

    describe '.display_total' do
      it { expect(wished_item_with_variant.display_total(currency: 'USD')).to eq Spree::Money.new((variant.amount_in('USD') * 3), currency: 'USD') }
    end
  end
end
