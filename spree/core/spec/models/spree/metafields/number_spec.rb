require 'spec_helper'

describe Spree::Metafields::Number, type: :model do
  let(:product) { create(:product) }
  let(:metafield_definition) { create(:metafield_definition, :number_field) }
  let(:metafield) { described_class.new(metafield_definition: metafield_definition, value: '123', resource: product) }

  describe 'Validations' do
    it 'returns false if the value is not a number' do
      metafield.value = 'not a number'
      expect(metafield.valid?).to be false
    end
  end

  describe '#serialize_value' do
    it 'returns the number' do
      expect(metafield.valid?).to be true
      expect(metafield.serialize_value).to be_kind_of(BigDecimal)
      expect(metafield.serialize_value).to eq(123)
    end
  end

  describe '#csv_value' do
    it 'returns the number as a string' do
      expect(metafield.csv_value).to be_kind_of(String)
      expect(metafield.csv_value).to eq('123.0')
    end
  end
end
