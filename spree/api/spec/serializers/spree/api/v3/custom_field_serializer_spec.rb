require 'spec_helper'

RSpec.describe Spree::Api::V3::CustomFieldSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product) }
  let(:custom_field_definition) { create(:custom_field_definition, resource_type: 'Spree::Product') }
  let(:custom_field) { create(:custom_field, resource: product, custom_field_definition: custom_field_definition, value: 'test value') }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'store serializer' do
    subject { described_class.new(custom_field, params: base_params).to_h }

    it 'includes key as full_key' do
      expect(subject['key']).to eq(custom_field.full_key)
      expect(subject['key']).to include('.')
    end

    it 'includes label' do
      expect(subject['label']).to eq(custom_field.label)
    end

    it 'includes type' do
      expect(subject['type']).to eq(custom_field.type)
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
  let(:product) { create(:product) }
  let(:custom_field_definition) { create(:custom_field_definition, resource_type: 'Spree::Product', storefront_visible: false) }
  let(:custom_field) { create(:custom_field, resource: product, custom_field_definition: custom_field_definition, value: 'admin value') }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'admin serializer' do
    subject { described_class.new(custom_field, params: base_params).to_h }

    it 'includes standard attributes' do
      expect(subject).to include(
        'key' => custom_field.full_key,
        'label' => custom_field.label,
        'type' => custom_field.type,
        'value' => 'admin value'
      )
    end

    it 'includes storefront_visible as false for admin-only definitions' do
      expect(subject['storefront_visible']).to be false
    end

    it 'includes storefront_visible as true for storefront-visible definitions' do
      public_definition = create(:custom_field_definition, resource_type: 'Spree::Product')
      public_custom_field = create(:custom_field, resource: product, custom_field_definition: public_definition, value: 'public value')
      result = described_class.new(public_custom_field, params: base_params).to_h
      expect(result['storefront_visible']).to be true
    end

    it 'does not include display_on' do
      expect(subject).not_to have_key('display_on')
    end
  end
end
