require 'spec_helper'

describe Spree::ProductType, type: :model do
  it_behaves_like 'metadata'

  describe 'fulfillment_types' do
    it 'defaults to shipping' do
      expect(described_class.new.fulfillment_types).to eq(['shipping'])
    end

    it 'persists an explicit value' do
      product_type = create(:product_type, fulfillment_types: %w[shipping pickup])

      expect(product_type.reload.fulfillment_types).to eq(%w[shipping pickup])
    end
  end

  describe '#digital?' do
    it 'is true only when digital is the sole fulfillment type' do
      expect(build(:product_type, fulfillment_types: ['digital'])).to be_digital
      expect(build(:product_type, fulfillment_types: %w[digital shipping])).not_to be_digital
      expect(build(:product_type)).not_to be_digital
    end
  end

  describe '#requires_shipping?' do
    it 'is true when shipping is among the fulfillment types' do
      expect(build(:product_type)).to be_requires_shipping
      expect(build(:product_type, fulfillment_types: ['digital'])).not_to be_requires_shipping
    end
  end

  describe 'deletion' do
    let(:product_type) { create(:product_type) }

    it 'is restricted while products use the type' do
      create(:product, product_type: product_type)

      expect(product_type.destroy).to be(false)
      expect(product_type.errors[:base]).to be_present
      expect(product_type.reload).to be_persisted
    end

    it 'destroys its joins when unused' do
      product_type.option_types << create(:option_type)

      expect { product_type.destroy }.to change(Spree::OptionTypeProductType, :count).by(-1)
    end
  end
end
