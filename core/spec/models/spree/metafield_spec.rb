require 'spec_helper'

RSpec.describe Spree::Metafield, type: :model do
  context 'Callbacks' do
    it 'sets the type from the metafield definition' do
      metafield_definition = create(:metafield_definition, metafield_type: 'Spree::Metafields::ShortText')
      metafield = create(:metafield, metafield_definition: metafield_definition)
      expect(metafield.type).to eq('Spree::Metafields::ShortText')
    end
  end

  context 'Validations' do
    it 'validates the type must match the metafield definition' do
      metafield_definition = create(:metafield_definition, metafield_type: 'Spree::Metafields::ShortText')
      metafield = build(:metafield, metafield_definition: metafield_definition, type: 'Spree::Metafields::LongText')
      expect(metafield.valid?).to be false
    end
  end

  context 'Scopes' do
    describe '.with_key' do
      it 'returns the metafields with the given key' do
        metafield_definition = create(:metafield_definition, namespace: 'custom', key: 'foo')
        metafield = create(:metafield, metafield_definition: metafield_definition)
        other_definition = create(:metafield_definition, namespace: 'custom', key: 'bar')
        create(:metafield, metafield_definition: other_definition)
        expect(described_class.with_key('custom', 'foo').ids).to contain_exactly(metafield.id)
      end
    end
  end

  describe '#serialize_value' do
    it 'returns the value' do
      metafield = build(:metafield, value: 'Test Value')
      expect(metafield.serialize_value).to eq('Test Value')
    end
  end
end
