require 'spec_helper'

describe Spree::CustomFields::Number, type: :model do
  let(:product) { create(:product) }
  let(:custom_field_definition) { create(:custom_field_definition, :number_field) }
  let(:custom_field) { described_class.new(custom_field_definition: custom_field_definition, value: '123', resource: product) }

  describe 'Validations' do
    it 'returns false if the value is not a number' do
      custom_field.value = 'not a number'
      expect(custom_field.valid?).to be false
    end
  end

  describe '#serialize_value' do
    it 'returns the number' do
      expect(custom_field.valid?).to be true
      expect(custom_field.serialize_value).to be_kind_of(BigDecimal)
      expect(custom_field.serialize_value).to eq(123)
    end
  end

  describe '#csv_value' do
    it 'returns the number as a string' do
      expect(custom_field.csv_value).to be_kind_of(String)
      expect(custom_field.csv_value).to eq('123.0')
    end
  end

  describe '.searchable? / .sortable?' do
    it 'is searchable and sortable' do
      expect(described_class.searchable?).to eq(true)
      expect(described_class.sortable?).to eq(true)
    end
  end
end
