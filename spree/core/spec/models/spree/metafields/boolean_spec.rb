require 'spec_helper'

describe Spree::Metafields::Boolean, type: :model do
  let(:metafield_definition) { create(:metafield_definition, :boolean_field) }
  let(:metafield) { described_class.new(metafield_definition: metafield_definition, value: 'true') }

  describe 'normalizes' do
    it 'normalizes the boolean value' do
      metafield.value = '0'
      expect(metafield.value).to eq('false')
      metafield.value = '1'
      expect(metafield.value).to eq('true')
    end
  end

  describe '#serialize_value' do
    it 'returns the boolean value' do
      expect(metafield.serialize_value).to eq(true)
    end
  end

  describe '#csv_value' do
    it 'returns the boolean value' do
      expect(metafield.csv_value).to eq('Yes')
    end
  end
end
