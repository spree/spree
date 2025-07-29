require 'spec_helper'

RSpec.describe Spree::MetafieldDefinition, type: :model do
  let(:metafield_definition) { build(:metafield_definition) }

  describe 'associations' do
    it { is_expected.to have_many(:metafields).class_name('Spree::Metafield').dependent(:destroy) }
  end

  describe 'scopes' do
    let!(:both_definition) { create(:metafield_definition, display_on: 'both') }
    let!(:front_end_definition) { create(:metafield_definition, :front_end_only) }
    let!(:back_end_definition) { create(:metafield_definition, :back_end_only) }
    let!(:product_definition) { create(:metafield_definition, owner_type: 'Spree::Product') }
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

    describe '.for_owner_type' do
      it 'returns definitions for specific owner type' do
        expect(described_class.for_owner_type('Spree::Product')).to include(product_definition)
        expect(described_class.for_owner_type('Spree::Product')).not_to include(variant_definition)

        expect(described_class.for_owner_type('Spree::Variant')).to include(variant_definition)
        expect(described_class.for_owner_type('Spree::Variant')).not_to include(product_definition)
      end
    end
  end

  describe 'factory' do
    it 'creates a valid metafield definition' do
      expect(metafield_definition).to be_valid
    end

    context 'with traits' do
      it 'creates front_end_only field' do
        front_end_field = build(:metafield_definition, :front_end_only)
        expect(front_end_field.display_on).to eq('front_end')
      end

      it 'creates back_end_only field' do
        back_end_field = build(:metafield_definition, :back_end_only)
        expect(back_end_field.display_on).to eq('back_end')
      end

      it 'creates short_text field' do
        short_text_field = build(:metafield_definition, :short_text_field)
        expect(short_text_field.kind).to eq('short_text')
        expect(short_text_field.key).to eq('title')
      end

      it 'creates long_text field' do
        long_text_field = build(:metafield_definition, :long_text_field)
        expect(long_text_field.kind).to eq('long_text')
        expect(long_text_field.key).to eq('description')
      end

      it 'creates number field' do
        number_field = build(:metafield_definition, :number_field)
        expect(number_field.kind).to eq('number')
        expect(number_field.key).to eq('priority')
      end

      it 'creates boolean field' do
        boolean_field = build(:metafield_definition, :boolean_field)
        expect(boolean_field.kind).to eq('boolean')
        expect(boolean_field.key).to eq('featured')
      end

      it 'creates json field' do
        json_field = build(:metafield_definition, :json_field)
        expect(json_field.kind).to eq('json')
        expect(json_field.key).to eq('settings')
      end

      it 'creates rich_text field' do
        rich_text_field = build(:metafield_definition, :rich_text_field)
        expect(rich_text_field.kind).to eq('rich_text')
        expect(rich_text_field.key).to eq('content')
      end

      it 'creates variant field' do
        variant_field = build(:metafield_definition, :for_variant)
        expect(variant_field.owner_type).to eq('Spree::Variant')
      end

      it 'creates user field' do
        user_field = build(:metafield_definition, :for_user)
        expect(user_field.owner_type).to eq('Spree::User')
      end
    end
  end
end
