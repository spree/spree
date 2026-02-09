require 'spec_helper'

RSpec.describe Spree::Metafields, type: :concern do
  let(:product) { create(:product) }

  describe 'associations' do
    it 'has many metafields' do
      expect(product).to respond_to(:metafields)
    end

    it 'has many public_metafields' do
      expect(product).to respond_to(:public_metafields)
    end

    it 'has many private_metafields' do
      expect(product).to respond_to(:private_metafields)
    end
  end

  describe '.with_metafield_key' do
    let!(:definition) { create(:metafield_definition, namespace: 'custom', key: 'foo', resource_type: 'Spree::Product') }
    let!(:metafield) { create(:metafield, resource: product, metafield_definition: definition) }

    it 'returns products with the given metafield key' do
      expect(Spree::Product.with_metafield_key('custom.foo')).to include(product)
    end

    it 'does not return products without the given metafield key' do
      other_product = create(:product)
      expect(Spree::Product.with_metafield_key('custom.foo')).not_to include(other_product)
    end
  end

  describe '.with_metafield_key_value' do
    let!(:definition) { create(:metafield_definition, namespace: 'custom', key: 'bar', resource_type: 'Spree::Product') }
    let!(:metafield) { create(:metafield, resource: product, metafield_definition: definition, value: 'baz') }

    it 'returns products with the given metafield key and value' do
      expect(Spree::Product.with_metafield_key_value('custom.bar', 'baz')).to include(product)
    end

    it 'does not return products with the key but different value' do
      expect(Spree::Product.with_metafield_key_value('custom.bar', 'other')).not_to include(product)
    end
  end

  describe '#set_metafield and #get_metafield' do
    it 'creates and retrieves a metafield by key_with_namespace' do
      expect {
        product.set_metafield('custom.foo', 'bar')
      }.to change { product.metafields.count }.by(1)

      metafield = product.get_metafield('custom.foo')
      expect(metafield).to be_present
      expect(metafield.value).to eq('bar')
      expect(metafield.metafield_definition.namespace).to eq('custom')
      expect(metafield.metafield_definition.key).to eq('foo')
    end

    it 'updates the value if the metafield already exists' do
      product.set_metafield('custom.foo', 'bar')
      expect {
        product.set_metafield('custom.foo', 'baz')
      }.not_to change { product.metafields.count }
      expect(product.get_metafield('custom.foo').value).to eq('baz')
    end
  end

  describe '#has_metafield?' do
    let!(:definition) { create(:metafield_definition, namespace: 'custom', key: 'foo', resource_type: 'Spree::Product') }

    it 'returns true if metafield exists for string key_with_namespace' do
      product.set_metafield('custom.foo', 'bar')
      expect(product.has_metafield?('custom.foo')).to be true
    end

    it 'returns false if metafield does not exist for string key_with_namespace' do
      expect(product.has_metafield?('custom.foo')).to be false
    end

    it 'returns true if metafield exists for MetafieldDefinition' do
      product.set_metafield('custom.foo', 'bar')
      expect(product.has_metafield?(definition)).to be true
    end

    it 'returns false if metafield does not exist for MetafieldDefinition' do
      expect(product.has_metafield?(definition)).to be false
    end

    it 'raises ArgumentError for invalid key_with_namespace' do
      expect {
        product.has_metafield?(123)
      }.to raise_error(ArgumentError)
    end
  end

  describe 'accepts_nested_attributes_for :metafields' do
    let!(:definition) { create(:metafield_definition, namespace: 'custom', key: 'foo', resource_type: 'Spree::Product') }

    it 'creates metafield via nested attributes' do
      attrs = {
        metafields_attributes: [
          {
            metafield_definition_id: definition.id,
            value: 'nested value',
            type: definition.metafield_type
          }
        ]
      }
      expect {
        product.update(attrs)
      }.to change { product.metafields.count }.by(1)
      expect(product.metafields.last.value).to eq('nested value')
    end

    it 'rejects metafield if metafield_definition_id is blank' do
      attrs = {
        metafields_attributes: [
          {
            metafield_definition_id: nil,
            value: 'should not be saved',
            type: definition.metafield_type
          }
        ]
      }
      expect {
        product.update(attrs)
      }.not_to change { product.metafields.count }
    end

    it 'rejects metafield if id and value are blank' do
      attrs = {
        metafields_attributes: [
          {
            metafield_definition_id: definition.id,
            value: '',
            id: nil,
            type: definition.metafield_type
          }
        ]
      }
      expect {
        product.update(attrs)
      }.not_to change { product.metafields.count }
    end

    context 'auto-destroy metafields with empty values' do
      let!(:metafield) do
        product.metafields.create!(
          metafield_definition: definition,
          value: 'initial value',
          type: definition.metafield_type
        )
      end

      it 'destroys existing metafield when value is set to empty string' do
        attrs = {
          metafields_attributes: [
            {
              id: metafield.id,
              metafield_definition_id: definition.id,
              value: '',
              type: definition.metafield_type
            }
          ]
        }
        expect {
          product.update(attrs)
        }.to change { product.metafields.count }.by(-1)
      end

      it 'destroys existing metafield when value is set to nil' do
        attrs = {
          metafields_attributes: [
            {
              id: metafield.id,
              metafield_definition_id: definition.id,
              value: nil,
              type: definition.metafield_type
            }
          ]
        }
        expect {
          product.update(attrs)
        }.to change { product.metafields.count }.by(-1)
      end

      it 'updates existing metafield when value is not empty' do
        attrs = {
          metafields_attributes: [
            {
              id: metafield.id,
              metafield_definition_id: definition.id,
              value: 'updated value',
              type: definition.metafield_type
            }
          ]
        }
        expect {
          product.update(attrs)
        }.not_to change { product.metafields.count }
        expect(metafield.reload.value).to eq('updated value')
      end

      it 'handles multiple metafields correctly' do
        other_definition = create(:metafield_definition, namespace: 'custom', key: 'bar', resource_type: 'Spree::Product')
        other_metafield = product.metafields.create!(
          metafield_definition: other_definition,
          value: 'other value',
          type: other_definition.metafield_type
        )

        attrs = {
          metafields_attributes: [
            {
              id: metafield.id,
              metafield_definition_id: definition.id,
              value: '',
              type: definition.metafield_type
            },
            {
              id: other_metafield.id,
              metafield_definition_id: other_definition.id,
              value: 'updated other value',
              type: other_definition.metafield_type
            }
          ]
        }
        expect {
          product.update(attrs)
        }.to change { product.metafields.count }.by(-1)
        expect(product.metafields.pluck(:id)).not_to include(metafield.id)
        expect(other_metafield.reload.value).to eq('updated other value')
      end
    end
  end
end
