require 'spec_helper'

RSpec.describe Spree::WishedVariant, type: :model do
  describe '#quantity' do
    subject { build(:wished_variant) }

    let!(:variant) { create(:variant)}
    let!(:wished_variant_with_product) {create(:wished_variant, variant: variant, quantity: 3)}

    it { is_expected.to respond_to(:quantity) }
    it { expect(subject.quantity).to eq(1) }

    context '#price' do
      it { expect(wished_variant_with_product.price(currency: 'USD')).to eq(variant.amount_in('USD')) }
    end

    context '#total' do
      it { expect(wished_variant_with_product.total(currency: 'USD')).to eql(variant.amount_in('USD') * 3) }
    end
  end
end
