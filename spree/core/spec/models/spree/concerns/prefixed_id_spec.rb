require 'spec_helper'

RSpec.describe Spree::PrefixedId do
  describe '.prefixed_id?' do
    it 'returns true for valid prefixed ID strings' do
      expect(described_class.prefixed_id?('prod_86Rf07xd4z')).to be true
      expect(described_class.prefixed_id?('tc_abc123XYZ')).to be true
      expect(described_class.prefixed_id?('seti_123')).to be true
    end

    it 'returns false for non-prefixed strings' do
      expect(described_class.prefixed_id?('12345')).to be false
      expect(described_class.prefixed_id?('')).to be false
      expect(described_class.prefixed_id?('no-underscore')).to be false
    end

    it 'returns false for non-string values' do
      expect(described_class.prefixed_id?(123)).to be false
      expect(described_class.prefixed_id?(nil)).to be false
    end
  end

  describe '#prefixed_id' do
    it 'returns a prefixed ID for persisted records' do
      product = create(:product)
      expect(product.prefixed_id).to start_with('prod_')
    end

    it 'returns nil for unsaved records' do
      product = build(:product)
      expect(product.prefixed_id).to be_nil
    end
  end

  describe '#assign_attributes — prefixed ID resolution' do
    context 'with belongs_to foreign keys' do
      let(:tax_category) { create(:tax_category) }

      it 'resolves prefixed ID for a belongs_to association' do
        product = create(:product)
        product.assign_attributes(tax_category_id: tax_category.prefixed_id)
        expect(product.tax_category_id).to eq(tax_category.id)
      end

      it 'leaves integer IDs untouched' do
        product = create(:product)
        product.assign_attributes(tax_category_id: tax_category.id)
        expect(product.tax_category_id).to eq(tax_category.id)
      end
    end

    context 'with non-FK columns ending in _id' do
      it 'preserves string values that look like prefixed IDs' do
        payment_method = create(:bogus_payment_method, stores: [Spree::Store.default])
        session = build(:payment_setup_session, payment_method: payment_method)
        session.assign_attributes(external_id: 'seti_123abc')

        expect(session.external_id).to eq('seti_123abc')
      end
    end

    context 'with has_many _ids setters' do
      let(:taxon1) { create(:taxon) }
      let(:taxon2) { create(:taxon, taxonomy: taxon1.taxonomy) }

      it 'resolves prefixed IDs for has_many associations' do
        product = create(:product)
        product.assign_attributes(taxon_ids: [taxon1.prefixed_id, taxon2.prefixed_id])
        expect(product.taxon_ids).to contain_exactly(taxon1.id, taxon2.id)
      end

      it 'passes through values for non-existent associations' do
        payment_method = create(:bogus_payment_method, stores: [Spree::Store.default])
        session = build(:payment_setup_session, payment_method: payment_method)

        # external_ids doesn't map to any association — values should pass through unchanged
        session.assign_attributes(external_id: 'seti_test456')
        expect(session.external_id).to eq('seti_test456')
      end
    end

    context 'with no prefixed IDs present' do
      it 'does not modify attributes' do
        product = build(:product)
        product.assign_attributes(name: 'Updated Name')
        expect(product.name).to eq('Updated Name')
      end
    end
  end

  describe '.find_by_prefix_id!' do
    it 'finds a record by prefixed ID' do
      product = create(:product)
      found = Spree::Product.find_by_prefix_id!(product.prefixed_id)
      expect(found).to eq(product)
    end

    it 'raises RecordNotFound for invalid prefixed ID' do
      expect {
        Spree::Product.find_by_prefix_id!('prod_nonexistent99')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '.find_by_param' do
    it 'finds by prefixed ID' do
      variant = create(:variant)
      found = Spree::Variant.find_by_param(variant.prefixed_id)
      expect(found).to eq(variant)
    end

    it 'falls back to integer ID' do
      variant = create(:variant)
      found = Spree::Variant.find_by_param(variant.id.to_s)
      expect(found).to eq(variant)
    end

    it 'returns nil for blank param' do
      expect(Spree::Variant.find_by_param(nil)).to be_nil
      expect(Spree::Variant.find_by_param('')).to be_nil
    end
  end
end
