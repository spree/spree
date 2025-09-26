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
    it 'returns the metafields with the given key' do
      metafield_definition = create(:metafield_definition, namespace: 'custom', key: 'foo')
      metafield = create(:metafield, metafield_definition: metafield_definition)
      expect(Spree::Metafield.with_key('custom', 'foo')).to include(metafield)
    end
  end
end
