require 'spec_helper'

RSpec.describe Spree::HasCustomFields, type: :concern do
  let(:product) { create(:product) }

  describe 'associations' do
    it 'has many custom_fields' do
      expect(product).to respond_to(:custom_fields)
    end

    it 'has many storefront_custom_fields' do
      expect(product).to respond_to(:storefront_custom_fields)
    end
  end

  describe '.with_custom_field_key' do
    let!(:definition) { create(:custom_field_definition, namespace: 'custom', key: 'foo', resource_type: 'Spree::Product') }
    let!(:custom_field) { create(:custom_field, resource: product, custom_field_definition: definition) }

    it 'returns products with the given custom_field key' do
      expect(Spree::Product.with_custom_field_key('custom.foo')).to include(product)
    end

    it 'does not return products without the given custom_field key' do
      other_product = create(:product)
      expect(Spree::Product.with_custom_field_key('custom.foo')).not_to include(other_product)
    end
  end

  describe '.with_custom_field_key_value' do
    let!(:definition) { create(:custom_field_definition, namespace: 'custom', key: 'bar', resource_type: 'Spree::Product') }
    let!(:custom_field) { create(:custom_field, resource: product, custom_field_definition: definition, value: 'baz') }

    it 'returns products with the given custom_field key and value' do
      expect(Spree::Product.with_custom_field_key_value('custom.bar', 'baz')).to include(product)
    end

    it 'does not return products with the key but different value' do
      expect(Spree::Product.with_custom_field_key_value('custom.bar', 'other')).not_to include(product)
    end
  end

  describe '#set_custom_field and #get_custom_field' do
    it 'creates and retrieves a custom_field by key_with_namespace' do
      expect {
        product.set_custom_field('custom.foo', 'bar')
      }.to change { product.custom_fields.count }.by(1)

      custom_field = product.get_custom_field('custom.foo')
      expect(custom_field).to be_present
      expect(custom_field.value).to eq('bar')
      expect(custom_field.custom_field_definition.namespace).to eq('custom')
      expect(custom_field.custom_field_definition.key).to eq('foo')
    end

    it 'updates the value if the custom_field already exists' do
      product.set_custom_field('custom.foo', 'bar')
      expect {
        product.set_custom_field('custom.foo', 'baz')
      }.not_to change { product.custom_fields.count }
      expect(product.get_custom_field('custom.foo').value).to eq('baz')
    end

    it 'accepts a CustomFieldDefinition instance' do
      definition = create(:custom_field_definition, namespace: 'custom', key: 'bar', resource_type: 'Spree::Product')

      product.set_custom_field(definition, 'value-from-instance')

      expect(product.get_custom_field('custom.bar').value).to eq('value-from-instance')
    end

    it 'accepts a prefixed-id String' do
      definition = create(:custom_field_definition, namespace: 'custom', key: 'pref', resource_type: 'Spree::Product')

      product.set_custom_field(definition.prefixed_id, 'value-from-prefixed')

      expect(product.get_custom_field('custom.pref').value).to eq('value-from-prefixed')
    end

    it 'accepts a raw integer id' do
      definition = create(:custom_field_definition, namespace: 'custom', key: 'intid', resource_type: 'Spree::Product')

      product.set_custom_field(definition.id, 'value-from-int')

      expect(product.get_custom_field('custom.intid').value).to eq('value-from-int')
    end

    it 'destroys an existing custom_field when the value is nil' do
      product.set_custom_field('custom.foo', 'bar')
      expect {
        product.set_custom_field('custom.foo', nil)
      }.to change { product.custom_fields.count }.by(-1)
    end

    it 'destroys an existing custom_field when the value is an empty/whitespace string' do
      product.set_custom_field('custom.foo', 'bar')
      expect {
        product.set_custom_field('custom.foo', '   ')
      }.to change { product.custom_fields.count }.by(-1)
    end

    it 'preserves Boolean false (not blank)' do
      definition = create(:custom_field_definition, namespace: 'custom', key: 'flag', resource_type: 'Spree::Product', field_type: 'Spree::CustomFields::Boolean')

      product.set_custom_field(definition, false)

      mf = product.get_custom_field('custom.flag')
      expect(mf).to be_present
      # Boolean custom_field serializes to a stringified value depending on adapter.
      expect(mf.value).to be_in(['false', 'f', false])
    end

    it 'preserves Numeric 0 (not blank)' do
      definition = create(:custom_field_definition, namespace: 'custom', key: 'count', resource_type: 'Spree::Product', field_type: 'Spree::CustomFields::Number')

      product.set_custom_field(definition, 0)

      mf = product.get_custom_field('custom.count')
      expect(mf).to be_present
      expect(mf.value.to_s).to eq('0')
    end

    it 'preserves an empty Array value (JSON custom_field)' do
      definition = create(:custom_field_definition, namespace: 'custom', key: 'tags_json', resource_type: 'Spree::Product', field_type: 'Spree::CustomFields::Json')

      product.set_custom_field(definition, '[]')

      mf = product.get_custom_field('custom.tags_json')
      expect(mf).to be_present
      expect(mf.value).to eq('[]')
    end

    it 'preserves an empty Hash value (JSON custom_field)' do
      definition = create(:custom_field_definition, namespace: 'custom', key: 'meta_json', resource_type: 'Spree::Product', field_type: 'Spree::CustomFields::Json')

      product.set_custom_field(definition, '{}')

      mf = product.get_custom_field('custom.meta_json')
      expect(mf).to be_present
      expect(mf.value).to eq('{}')
    end

    it 'raises ArgumentError on a prefixed-id-shaped string that decodes to no real definition' do
      # Sqids decodes any alphanumeric string to *some* integer; the
      # existence check ensures we don't silently address a phantom id.
      expect {
        product.set_custom_field('cfdef_garbage', 'x')
      }.to raise_error(ArgumentError, /Unknown custom field definition id/)
    end

    it 'raises ArgumentError on a bare non-numeric string' do
      expect {
        product.set_custom_field('nope', 'x')
      }.to raise_error(ArgumentError, /Invalid custom field definition reference/)
    end

    it 'raises ArgumentError on a non-supported type' do
      expect {
        product.set_custom_field(Object.new, 'x')
      }.to raise_error(ArgumentError, /Invalid definition_or_key/)
    end
  end

  describe '#has_custom_field?' do
    let!(:definition) { create(:custom_field_definition, namespace: 'custom', key: 'foo', resource_type: 'Spree::Product') }

    it 'returns true if custom_field exists for string key_with_namespace' do
      product.set_custom_field('custom.foo', 'bar')
      expect(product.has_custom_field?('custom.foo')).to be true
    end

    it 'returns false if custom_field does not exist for string key_with_namespace' do
      expect(product.has_custom_field?('custom.foo')).to be false
    end

    it 'returns true if custom_field exists for CustomFieldDefinition' do
      product.set_custom_field('custom.foo', 'bar')
      expect(product.has_custom_field?(definition)).to be true
    end

    it 'returns false if custom_field does not exist for CustomFieldDefinition' do
      expect(product.has_custom_field?(definition)).to be false
    end

    it 'raises ArgumentError for invalid key_with_namespace' do
      expect {
        product.has_custom_field?(123)
      }.to raise_error(ArgumentError)
    end
  end

  describe 'accepts_nested_attributes_for :custom_fields' do
    let!(:definition) { create(:custom_field_definition, namespace: 'custom', key: 'foo', resource_type: 'Spree::Product') }

    it 'creates custom_field via nested attributes' do
      attrs = {
        custom_fields_attributes: [
          {
            custom_field_definition_id: definition.id,
            value: 'nested value',
            type: definition.field_type_class_name
          }
        ]
      }
      expect {
        product.update(attrs)
      }.to change { product.custom_fields.count }.by(1)
      expect(product.custom_fields.last.value).to eq('nested value')
    end

    it 'rejects custom_field if custom_field_definition_id is blank' do
      attrs = {
        custom_fields_attributes: [
          {
            custom_field_definition_id: nil,
            value: 'should not be saved',
            type: definition.field_type_class_name
          }
        ]
      }
      expect {
        product.update(attrs)
      }.not_to change { product.custom_fields.count }
    end

    it 'rejects custom_field if id and value are blank' do
      attrs = {
        custom_fields_attributes: [
          {
            custom_field_definition_id: definition.id,
            value: '',
            id: nil,
            type: definition.field_type_class_name
          }
        ]
      }
      expect {
        product.update(attrs)
      }.not_to change { product.custom_fields.count }
    end

    context 'auto-destroy custom_fields with empty values' do
      let!(:custom_field) do
        create(:custom_field, resource: product, custom_field_definition: definition,
                             value: 'initial value', type: definition.field_type_class_name)
      end

      it 'destroys existing custom_field when value is set to empty string' do
        attrs = {
          custom_fields_attributes: [
            {
              id: custom_field.id,
              custom_field_definition_id: definition.id,
              value: '',
              type: definition.field_type_class_name
            }
          ]
        }
        expect {
          product.update(attrs)
        }.to change { product.custom_fields.count }.by(-1)
      end

      it 'destroys existing custom_field when value is set to nil' do
        attrs = {
          custom_fields_attributes: [
            {
              id: custom_field.id,
              custom_field_definition_id: definition.id,
              value: nil,
              type: definition.field_type_class_name
            }
          ]
        }
        expect {
          product.update(attrs)
        }.to change { product.custom_fields.count }.by(-1)
      end

      it 'updates existing custom_field when value is not empty' do
        attrs = {
          custom_fields_attributes: [
            {
              id: custom_field.id,
              custom_field_definition_id: definition.id,
              value: 'updated value',
              type: definition.field_type_class_name
            }
          ]
        }
        expect {
          product.update(attrs)
        }.not_to change { product.custom_fields.count }
        expect(custom_field.reload.value).to eq('updated value')
      end

      it 'handles multiple custom_fields correctly' do
        other_definition = create(:custom_field_definition, namespace: 'custom', key: 'bar', resource_type: 'Spree::Product')
        other_custom_field = create(:custom_field, resource: product, custom_field_definition: other_definition,
                                                   value: 'other value', type: other_definition.field_type_class_name)

        attrs = {
          custom_fields_attributes: [
            {
              id: custom_field.id,
              custom_field_definition_id: definition.id,
              value: '',
              type: definition.field_type_class_name
            },
            {
              id: other_custom_field.id,
              custom_field_definition_id: other_definition.id,
              value: 'updated other value',
              type: other_definition.field_type_class_name
            }
          ]
        }
        expect {
          product.update(attrs)
        }.to change { product.custom_fields.count }.by(-1)
        expect(product.custom_fields.pluck(:id)).not_to include(custom_field.id)
        expect(other_custom_field.reload.value).to eq('updated other value')
      end
    end
  end

  describe '#metafields_attributes=' do
    let(:definition) { create(:custom_field_definition, namespace: 'custom', key: 'legacy', resource_type: 'Spree::Product') }

    # Legacy payloads name the foreign key `metafield_definition_id`, which the
    # current writer would otherwise reject and silently drop.
    it 'accepts the legacy definition key' do
      expect {
        product.metafields_attributes = [{ metafield_definition_id: definition.id, value: 'legacy value' }]
        product.save!
      }.to change { product.custom_fields.count }.by(1)

      expect(product.get_custom_field('custom.legacy').value).to eq('legacy value')
    end

    it 'still accepts the current definition key' do
      expect {
        product.metafields_attributes = [{ custom_field_definition_id: definition.id, value: 'current value' }]
        product.save!
      }.to change { product.custom_fields.count }.by(1)
    end
  end
end
