require 'spec_helper'

describe Spree::TaxCategory, type: :model do
  context 'default tax category' do
    let(:tax_category) { create(:tax_category) }
    let(:new_tax_category) { create(:tax_category) }

    before do
      tax_category.update_column(:is_default, true)
    end

    it 'undefaults the previous default tax category' do
      new_tax_category.update(is_default: true)
      expect(new_tax_category.is_default).to be true

      tax_category.reload
      expect(tax_category.is_default).to be false
    end

    it 'undefaults the previous default tax category except when updating the existing default tax category' do
      tax_category.update_column(:description, 'Updated description')

      tax_category.reload
      expect(tax_category.is_default).to be true
    end
  end

  describe '.default' do
    it 'returns the default tax category' do
      tax_category = create(:tax_category, is_default: true)
      expect(Spree::TaxCategory.default).to eq(tax_category)
    end
  end

  describe 'store binding' do
    it 'falls back to the current store' do
      expect(create(:tax_category).store).to eq(@default_store)
    end

    it 'allows the same name in another store' do
      other_store = create(:store)
      create(:tax_category, name: 'Standard')

      expect(build(:tax_category, name: 'Standard', store: other_store)).to be_valid
    end

    it 'rejects a duplicate name within the same store, ignoring case' do
      create(:tax_category, name: 'Standard')

      expect(build(:tax_category, name: 'standard')).not_to be_valid
    end

    it 'ignores soft-deleted rows when checking the name' do
      create(:tax_category, name: 'Standard').destroy

      expect(build(:tax_category, name: 'Standard')).to be_valid
    end
  end

  describe '#destroy' do
    let!(:tax_category) { create(:tax_category) }
    let!(:tax_rate) { create(:tax_rate, tax_category: tax_category) }
    let!(:product) { create(:product, tax_category: tax_category) }
    let!(:variant) { create(:variant, product: product, tax_category: tax_category) }

    it 'removes all tax rates' do
      expect { tax_category.destroy }.to change { Spree::TaxRate.count }.by(-1)
    end

    it 'nullifies all products and variants' do
      expect { tax_category.destroy }.not_to change { Spree::Product.count }
      expect { tax_category.destroy }.not_to change { Spree::Variant.count }
      expect(product.reload.tax_category).to be_nil
      expect(variant.reload.tax_category).to be_nil
    end
  end
end
