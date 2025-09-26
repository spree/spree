require 'spec_helper'

RSpec.describe Spree::MetafieldDefinition, type: :model do
  let(:metafield_definition) { build(:metafield_definition) }

  describe 'scopes' do
    let!(:both_definition) { create(:metafield_definition, display_on: 'both') }
    let!(:front_end_definition) { create(:metafield_definition, :front_end_only) }
    let!(:back_end_definition) { create(:metafield_definition, :back_end_only) }
    let!(:product_definition) { create(:metafield_definition, resource_type: 'Spree::Product') }
    let!(:variant_definition) { create(:metafield_definition, :for_variant) }

    describe '.available' do
      it 'returns only both definitions (from DisplayOn concern)' do
        expect(described_class.available).to include(both_definition)
        expect(described_class.available).not_to include(front_end_definition)
        expect(described_class.available).not_to include(back_end_definition)
      end
    end

    describe '.available_on_front_end' do
      it 'returns public definitions (front_end and both)' do
        expect(described_class.available_on_front_end).to include(front_end_definition, both_definition)
        expect(described_class.available_on_front_end).not_to include(back_end_definition)
      end
    end

    describe '.available_on_back_end' do
      it 'returns admin definitions (back_end and both)' do
        expect(described_class.available_on_back_end).to include(back_end_definition, both_definition)
        expect(described_class.available_on_back_end).not_to include(front_end_definition)
      end
    end

    describe '.for_resource_type' do
      it 'returns definitions for specific resource type' do
        expect(described_class.for_resource_type('Spree::Product')).to include(product_definition)
        expect(described_class.for_resource_type('Spree::Product')).not_to include(variant_definition)

        expect(described_class.for_resource_type('Spree::Variant')).to include(variant_definition)
        expect(described_class.for_resource_type('Spree::Variant')).not_to include(product_definition)
      end
    end
  end
end
