require 'spec_helper'

describe Spree::Metafields::Json, type: :model do
  let(:product) { create(:product) }
  let(:metafield_definition) { create(:metafield_definition, :json_field) }
  let(:metafield) { described_class.new(metafield_definition: metafield_definition, value: value, resource: product) }

  describe 'Validations' do
    context 'when value is a valid JSON string' do
      let(:value) { '{"foo": "bar", "baz": 123}' }

      it 'parses and stores the value as a Hash' do
        expect(metafield.valid?).to be true
        expect(metafield.value).to eq({ 'foo' => 'bar', 'baz' => 123 })
      end
    end

    context 'when value is a blank string' do
      let(:value) { '   ' }

      it 'sets value to nil and is invalid' do
        expect(metafield.valid?).to be false
        expect(metafield.value).to be_nil
        expect(metafield.errors[:value]).to be_present
      end
    end

    context 'when value is an invalid JSON string' do
      let(:value) { '{foo: bar}' }

      it 'raises JSON::ParserError on assignment' do
        expect {
          metafield.valid?
        }.to raise_error(JSON::ParserError)
      end
    end

    context 'when value is already a Hash' do
      let(:value) { { 'foo' => 'bar' } }

      it 'keeps the value as a Hash' do
        expect(metafield.valid?).to be true
        expect(metafield.value).to eq({ 'foo' => 'bar' })
      end
    end

    context 'when value is nil' do
      let(:value) { nil }

      it 'is invalid' do
        expect(metafield.valid?).to be false
        expect(metafield.errors[:value]).to be_present
      end
    end
  end

  describe '#serialize_value' do
    let(:value) { { 'foo' => 'bar', 'baz' => [1, 2, 3] } }

    it 'returns the value as is (Hash)' do
      expect(metafield.serialize_value).to eq({ 'foo' => 'bar', 'baz' => [1, 2, 3] })
    end
  end
end
