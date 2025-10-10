require 'spec_helper'

describe Spree::Metafields::Json, type: :model do
  let(:product) { create(:product) }
  let(:metafield_definition) { create(:metafield_definition, metafield_type: 'Spree::Metafields::Json') }
  let(:metafield) { described_class.new(metafield_definition: metafield_definition, value: '{"key": "value"}', resource: product) }

  describe 'Validations' do
    it 'returns false if the value is not valid JSON' do
      metafield.value = 'not valid json'
      expect(metafield.valid?).to be false
      expect(metafield.errors[:value]).to include(/must be valid JSON/)
    end

    it 'returns true for valid JSON object' do
      metafield.value = '{"key": "value", "nested": {"foo": "bar"}}'
      expect(metafield.valid?).to be true
    end

    it 'returns true for valid JSON array' do
      metafield.value = '[1, 2, 3, "test"]'
      expect(metafield.valid?).to be true
    end

    it 'returns true for valid JSON string' do
      metafield.value = '"simple string"'
      expect(metafield.valid?).to be true
    end

    it 'returns true for valid JSON number' do
      metafield.value = '123'
      expect(metafield.valid?).to be true
    end

    it 'returns true for valid JSON boolean' do
      metafield.value = 'true'
      expect(metafield.valid?).to be true
    end

    it 'returns true for valid JSON null' do
      metafield.value = 'null'
      expect(metafield.valid?).to be true
    end
  end

  describe '#serialize_value' do
    it 'returns parsed JSON object' do
      metafield.value = '{"key": "value", "number": 42}'
      expect(metafield.serialize_value).to eq({ 'key' => 'value', 'number' => 42 })
    end

    it 'returns parsed JSON array' do
      metafield.value = '[1, 2, 3]'
      expect(metafield.serialize_value).to eq([1, 2, 3])
    end

    it 'returns original value if parsing fails' do
      allow(JSON).to receive(:parse).and_raise(JSON::ParserError)
      expect(metafield.serialize_value).to eq('{"key": "value"}')
    end
  end
end
