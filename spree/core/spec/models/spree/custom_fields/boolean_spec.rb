require 'spec_helper'

describe Spree::CustomFields::Boolean, type: :model do
  let(:custom_field_definition) { create(:custom_field_definition, :boolean_field) }
  let(:custom_field) { described_class.new(custom_field_definition: custom_field_definition, value: 'true') }

  describe 'normalizes' do
    it 'normalizes the boolean value' do
      custom_field.value = '0'
      expect(custom_field.value).to eq('false')
      custom_field.value = '1'
      expect(custom_field.value).to eq('true')
    end
  end

  describe '#serialize_value' do
    it 'returns the boolean value' do
      expect(custom_field.serialize_value).to eq(true)
    end
  end

  describe '#csv_value' do
    it 'returns the boolean value' do
      expect(custom_field.csv_value).to eq('Yes')
    end
  end

  describe '.searchable? / .sortable?' do
    it 'is neither searchable nor sortable (filterable in Phase 6)' do
      expect(described_class.searchable?).to eq(false)
      expect(described_class.sortable?).to eq(false)
    end
  end
end
