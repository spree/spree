require 'spec_helper'

RSpec.describe Spree::Api::V3::CustomFieldSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store]) }
  let(:metafield_definition) { create(:metafield_definition, resource_type: 'Spree::Product', display_on: 'both') }
  let(:metafield) { create(:metafield, resource: product, metafield_definition: metafield_definition, value: 'test value') }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'store serializer' do
    subject { described_class.new(metafield, params: base_params).to_h }

    it 'includes key as full_key' do
      expect(subject['key']).to eq(metafield.full_key)
      expect(subject['key']).to include('.')
    end

    it 'includes label' do
      expect(subject['label']).to eq(metafield.label)
    end

    it 'includes type' do
      expect(subject['type']).to eq(metafield.type)
    end

    it 'includes serialized value' do
      expect(subject['value']).to eq('test value')
    end

    it 'does not include display_on' do
      expect(subject).not_to have_key('display_on')
    end
  end
end

RSpec.describe Spree::Api::V3::Admin::CustomFieldSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store]) }
  let(:metafield_definition) { create(:metafield_definition, resource_type: 'Spree::Product', display_on: 'back_end') }
  let(:metafield) { create(:metafield, resource: product, metafield_definition: metafield_definition, value: 'admin value') }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'admin serializer' do
    subject { described_class.new(metafield, params: base_params).to_h }

    it 'includes standard attributes' do
      expect(subject).to include(
        'key' => metafield.full_key,
        'label' => metafield.label,
        'type' => metafield.type,
        'value' => 'admin value'
      )
    end

    it 'includes storefront_visible as false for back_end display_on' do
      expect(subject['storefront_visible']).to be false
    end

    it 'includes storefront_visible as true for both display_on' do
      public_definition = create(:metafield_definition, resource_type: 'Spree::Product', display_on: 'both')
      public_metafield = create(:metafield, resource: product, metafield_definition: public_definition, value: 'public value')
      result = described_class.new(public_metafield, params: base_params).to_h
      expect(result['storefront_visible']).to be true
    end

    it 'does not include display_on' do
      expect(subject).not_to have_key('display_on')
    end
  end
end
