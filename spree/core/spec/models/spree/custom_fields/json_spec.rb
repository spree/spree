require 'spec_helper'

describe Spree::CustomFields::Json, type: :model do
  let(:product) { create(:product) }
  let(:custom_field_definition) { create(:custom_field_definition, field_type: 'Spree::CustomFields::Json') }
  let(:custom_field) { described_class.new(custom_field_definition: custom_field_definition, value: '{"key": "value"}', resource: product) }

  describe 'Validations' do
    it 'returns false if the value is not valid JSON' do
      custom_field.value = 'not valid json'
      expect(custom_field.valid?).to be false
      expect(custom_field.errors[:value]).to include(/must be valid JSON/)
    end

    it 'returns true for valid JSON object' do
      custom_field.value = '{"key": "value", "nested": {"foo": "bar"}}'
      expect(custom_field.valid?).to be true
    end

    it 'returns true for valid JSON array' do
      custom_field.value = '[1, 2, 3, "test"]'
      expect(custom_field.valid?).to be true
    end

    it 'returns true for valid JSON string' do
      custom_field.value = '"simple string"'
      expect(custom_field.valid?).to be true
    end

    it 'returns true for valid JSON number' do
      custom_field.value = '123'
      expect(custom_field.valid?).to be true
    end

    it 'returns true for valid JSON boolean' do
      custom_field.value = 'true'
      expect(custom_field.valid?).to be true
    end

    it 'returns true for valid JSON null' do
      custom_field.value = 'null'
      expect(custom_field.valid?).to be true
    end
  end

  describe '#serialize_value' do
    it 'returns parsed JSON object' do
      custom_field.value = '{"key": "value", "number": 42}'
      expect(custom_field.serialize_value).to eq({ 'key' => 'value', 'number' => 42 })
    end

    it 'returns parsed JSON array' do
      custom_field.value = '[1, 2, 3]'
      expect(custom_field.serialize_value).to eq([1, 2, 3])
    end

    it 'returns original value if parsing fails' do
      allow(JSON).to receive(:parse).and_raise(JSON::ParserError)
      expect(custom_field.serialize_value).to eq('{"key": "value"}')
    end
  end
end
