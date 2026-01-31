require 'spec_helper'

RSpec.describe Spree::Api::V3::MetafieldSerializer do
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

    it 'includes name' do
      expect(subject['name']).to eq(metafield.name)
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

RSpec.describe Spree::Api::V3::Admin::MetafieldSerializer do
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
        'name' => metafield.name,
        'type' => metafield.type,
        'value' => 'admin value'
      )
    end

    it 'includes display_on' do
      expect(subject['display_on']).to eq('back_end')
    end
  end
end
