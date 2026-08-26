require 'spec_helper'

RSpec.describe Spree::HasExternalReferences do
  let(:store) { @default_store }
  let(:product) { create(:product, store: store) }

  describe '#set_external_id' do
    it 'creates a reference carrying the record store' do
      reference = product.set_external_id('erp', 'MAT-100')

      expect(reference).to be_persisted
      expect(reference.store).to eq(store)
      expect(product.external_id_for('erp')).to eq('MAT-100')
    end

    it 'updates the existing reference for that system rather than adding a second' do
      product.set_external_id('erp', 'MAT-100')

      expect { product.set_external_id('erp', 'MAT-200') }.not_to change { product.external_references.count }
      expect(product.external_id_for('erp')).to eq('MAT-200')
    end

    it 'keeps one record identifiable in several systems at once' do
      product.set_external_id('erp', 'MAT-100')
      product.set_external_id('pim', 'SKU-1')

      expect(product.external_id_for('erp')).to eq('MAT-100')
      expect(product.external_id_for('pim')).to eq('SKU-1')
    end

    it 'removes the reference when given a blank id' do
      product.set_external_id('erp', 'MAT-100')

      expect { product.set_external_id('erp', '') }.to change { product.external_references.count }.by(-1)
      expect(product.external_id_for('erp')).to be_nil
    end

    it 'stores connector bookkeeping in metadata' do
      reference = product.set_external_id('erp', 'MAT-100', metadata: { 'etag' => 'abc' })

      expect(reference.metadata['etag']).to eq('abc')
    end
  end

  describe '#external_id_for' do
    it 'reads through a loaded association without a further query' do
      product.set_external_id('erp', 'MAT-100')
      loaded = Spree::Product.includes(:external_references).find(product.id)

      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name].to_s.in?(['SCHEMA', 'TRANSACTION']) }

      result = ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
        loaded.external_id_for('erp')
      end

      expect(queries).to eq(0)
      expect(result).to eq('MAT-100')
    end

    it 'matches case-insensitively on the system key' do
      product.set_external_id('erp', 'MAT-100')

      expect(product.external_id_for('ERP')).to eq('MAT-100')
    end
  end

  describe '.with_external_id' do
    it 'finds the record the external system knows' do
      product.set_external_id('erp', 'MAT-100')

      expect(Spree::Product.with_external_id('erp', 'MAT-100').take).to eq(product)
    end

    it 'matches nothing when no reference matches' do
      expect(Spree::Product.with_external_id('erp', 'NOPE')).to be_empty
    end

    it 'honours the scope it is chained onto, so another store is invisible' do
      other_store = create(:store)
      other_product = create(:product, store: other_store)
      other_product.set_external_id('erp', 'MAT-100')

      expect(store.products.with_external_id('erp', 'MAT-100')).to be_empty
      expect(other_store.products.with_external_id('erp', 'MAT-100').take).to eq(other_product)
    end
  end

  describe '#assign_external_references' do
    it 'writes the systems named and leaves the others alone' do
      product.set_external_id('pim', 'SKU-1')

      product.assign_external_references([{ system: 'erp', external_id: 'MAT-100' }])

      expect(product.external_id_for('erp')).to eq('MAT-100')
      expect(product.external_id_for('pim')).to eq('SKU-1')
    end

    # The same map shape the admin serializers render, so a caller can hand
    # back exactly what it read.
    it 'accepts a system => id map as well as a list' do
      product.assign_external_references(erp: 'MAT-100', pim: 'SKU-1')

      expect(product.external_id_for('erp')).to eq('MAT-100')
      expect(product.external_id_for('pim')).to eq('SKU-1')
    end

    it 'ignores entries without a system' do
      expect { product.assign_external_references([{ external_id: 'MAT-100' }]) }.
        not_to change { product.external_references.count }
    end
  end

  describe 'store resolution for records that reach the store through a parent' do
    it 'uses the product store for a variant' do
      variant = create(:variant, product: product)

      expect(variant.set_external_id('erp', 'V-1').store).to eq(store)
    end
  end

  describe 'lifecycle' do
    it 'destroys the references with the record' do
      product.set_external_id('erp', 'MAT-100')

      expect { product.destroy }.to change { Spree::ExternalReference.count }.by(-1)
    end
  end
end
