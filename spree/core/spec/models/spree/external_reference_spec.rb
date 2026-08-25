require 'spec_helper'

RSpec.describe Spree::ExternalReference, type: :model do
  let(:store) { @default_store }
  let(:product) { create(:product, store: store) }

  describe 'normalization' do
    it 'downcases and strips the system key' do
      reference = create(:external_reference, resource: product, store: store, system: '  ERP  ')

      expect(reference.system).to eq('erp')
    end

    it 'strips the external id' do
      reference = create(:external_reference, resource: product, store: store, external_id: '  MAT-100 ')

      expect(reference.external_id).to eq('MAT-100')
    end
  end

  describe 'validation' do
    it 'rejects a system key that is not a plain lowercase token' do
      reference = build(:external_reference, resource: product, store: store, system: 'my system!')

      expect(reference).not_to be_valid
      expect(reference.errors[:system]).to be_present
    end

    it 'allows one reference per system for the same record' do
      create(:external_reference, resource: product, store: store, system: 'erp', external_id: 'MAT-100')
      pim = build(:external_reference, resource: product, store: store, system: 'pim', external_id: 'SKU-1')

      expect(pim).to be_valid
    end

    it 'rejects a second reference for the same record and system' do
      create(:external_reference, resource: product, store: store, system: 'erp', external_id: 'MAT-100')
      duplicate = build(:external_reference, resource: product, store: store, system: 'erp', external_id: 'MAT-200')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:resource_id]).to be_present
    end

    it 'rejects the same external id pointing at two records in one system' do
      create(:external_reference, resource: product, store: store, system: 'erp', external_id: 'MAT-100')
      other = build(:external_reference, resource: create(:product, store: store), store: store,
                                         system: 'erp', external_id: 'MAT-100')

      expect(other).not_to be_valid
      expect(other.errors[:external_id]).to be_present
    end

    it 'allows the same external id in two different systems' do
      create(:external_reference, resource: product, store: store, system: 'erp', external_id: 'MAT-100')
      pim = build(:external_reference, resource: create(:product, store: store), store: store,
                                       system: 'pim', external_id: 'MAT-100')

      expect(pim).to be_valid
    end

    it 'allows the same external id in another store' do
      other_store = create(:store)
      create(:external_reference, resource: product, store: store, system: 'erp', external_id: 'MAT-100')
      elsewhere = build(:external_reference, resource: create(:product, store: other_store), store: other_store,
                                             system: 'erp', external_id: 'MAT-100')

      expect(elsewhere).to be_valid
    end
  end

  describe 'database constraints' do
    it 'refuses a duplicate (store, system, resource) at the database level' do
      create(:external_reference, resource: product, store: store, system: 'erp', external_id: 'MAT-100')
      duplicate = build(:external_reference, resource: product, store: store, system: 'erp', external_id: 'MAT-200')

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'refuses a duplicate (store, system, external_id) at the database level' do
      create(:external_reference, resource: product, store: store, system: 'erp', external_id: 'MAT-100')
      duplicate = build(:external_reference, resource: create(:product, store: store), store: store,
                                             system: 'erp', external_id: 'MAT-100')

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
