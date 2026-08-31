require 'spec_helper'

RSpec.describe Spree::Variant, 'quantity rules' do
  let(:store) { @default_store }
  let(:variant) { create(:variant, product: create(:product, store: store)) }

  describe 'validations' do
    it 'refuses a zero or negative rule' do
      expect(build(:variant, minimum_order_quantity: 0)).not_to be_valid
      expect(build(:variant, order_multiple: -1)).not_to be_valid
      expect(build(:variant, units_per_carton: 0)).not_to be_valid
    end

    it 'refuses a purchase unit outside the vocabulary' do
      expect(build(:variant, purchase_unit: 'pallet')).not_to be_valid
    end

    it 'requires a carton size when the purchase unit is cartons' do
      variant = build(:variant, purchase_unit: 'carton', units_per_carton: nil)

      expect(variant).not_to be_valid
      expect(variant.errors[:units_per_carton]).to be_present
    end

    # An order multiple that straddles carton boundaries can never ship whole,
    # so the merchant hears about it at edit time.
    it 'refuses an order multiple that does not line up with the carton' do
      expect(build(:variant, order_multiple: 24, units_per_carton: 20)).not_to be_valid
    end

    it 'accepts a multiple that divides the carton or is a multiple of it' do
      expect(build(:variant, order_multiple: 12, units_per_carton: 24)).to be_valid
      expect(build(:variant, order_multiple: 48, units_per_carton: 24)).to be_valid
    end
  end

  describe '#quantity_rule' do
    it 'reads the variant columns' do
      variant.update!(minimum_order_quantity: 48, order_multiple: 24)

      expect(variant.quantity_rule.minimum).to eq(48)
      expect(variant.quantity_rule.multiple).to eq(24)
    end

    it 'is unrestricted when the columns are empty' do
      expect(variant.quantity_rule).to be_unrestricted
    end
  end

  describe '#sold_by_carton? and #cartons_for' do
    it 'counts part cartons as whole ones' do
      variant.update!(purchase_unit: 'carton', units_per_carton: 24)

      expect(variant).to be_sold_by_carton
      expect(variant.cartons_for(48)).to eq(2)
      expect(variant.cartons_for(25)).to eq(2)
    end

    it 'answers nothing without a carton size' do
      expect(variant.cartons_for(48)).to be_nil
      expect(variant).not_to be_sold_by_carton
    end
  end
end
