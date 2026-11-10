require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ProductSerializer do
  let(:store) { @default_store }
  let(:product) { create(:product) }
  let(:base_params) { { store: store, currency: 'USD' } }

  describe 'admin serializer' do
    subject { described_class.new(product, params: base_params).to_h }

    it 'includes admin-only attributes' do
      expect(subject.keys).to include('deleted_at', 'status', 'created_at', 'updated_at')
    end

    it 'includes all custom fields with storefront_visible when expanded' do
      public_def = create(:custom_field_definition, resource_type: 'Spree::Product')
      private_def = create(:custom_field_definition, :admin_only, resource_type: 'Spree::Product')
      create(:custom_field, resource: product, custom_field_definition: public_def, value: 'public')
      create(:custom_field, resource: product, custom_field_definition: private_def, value: 'private')

      result = described_class.new(product, params: base_params.merge(expand: ['custom_fields'])).to_h
      expect(result['custom_fields'].length).to eq(2)
      expect(result['custom_fields']).to all(have_key('storefront_visible'))
    end
  end
end
