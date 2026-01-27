require 'spec_helper'

describe Spree::Api::V2::Platform::MetafieldSerializer do
  let(:product) { create(:product) }

  subject { described_class.new(Spree::Metafield.find(metafield.id)) }

  context 'with ShortText type' do
    let(:metafield_definition) { create(:metafield_definition, namespace: 'custom', key: 'test_field', metafield_type: 'Spree::Metafields::ShortText') }
    let(:metafield) { create(:metafield, metafield_definition: metafield_definition, value: 'Test Value', resource: product) }

    it { expect(subject.serializable_hash).to be_kind_of(Hash) }

    it do
      expect(subject.serializable_hash).to eq(
        {
          data: {
            id: metafield.id.to_s,
            type: :metafield,
            attributes: {
              name: metafield.name,
              type: metafield.type,
              display_on: metafield.display_on,
              key: 'custom.test_field',
              value: 'Test Value'
            }
          }
        }
      )
    end
  end

  context 'with Number type' do
    let(:metafield_definition) { create(:metafield_definition, namespace: 'custom', key: 'test_field', metafield_type: 'Spree::Metafields::Number') }
    let(:metafield) { create(:metafield, metafield_definition: metafield_definition, value: '123.45', resource: product, type: 'Spree::Metafields::Number') }

    it do
      expect(subject.serializable_hash[:data][:attributes][:value]).to be_kind_of(BigDecimal)
      expect(subject.serializable_hash[:data][:attributes][:value]).to eq(BigDecimal('123.45'))
    end
  end

  context 'with Json type' do
    let(:metafield_definition) { create(:metafield_definition, namespace: 'custom', key: 'test_field', metafield_type: 'Spree::Metafields::Json') }
    let(:metafield) { create(:metafield, metafield_definition: metafield_definition, value: '{"key": "value", "number": 42, "nested": {"foo": "bar"}}', resource: product, type: 'Spree::Metafields::Json') }
    subject { described_class.new(Spree::Metafield.find(metafield.id)) }

    it do
      expect(subject.serializable_hash[:data][:attributes][:value]).to be_kind_of(Hash)
      expect(subject.serializable_hash[:data][:attributes][:value]).to eq({ 'key' => 'value', 'number' => 42, 'nested' => { 'foo' => 'bar' } })
    end
  end

  context 'with Json array type' do
    let(:metafield_definition) { create(:metafield_definition, namespace: 'custom', key: 'test_field', metafield_type: 'Spree::Metafields::Json') }
    let(:metafield) { create(:metafield, metafield_definition: metafield_definition, value: '[1, 2, 3, "test"]', resource: product, type: 'Spree::Metafields::Json') }
    subject { described_class.new(Spree::Metafield.find(metafield.id)) }

    it do
      expect(subject.serializable_hash[:data][:attributes][:value]).to be_kind_of(Array)
      expect(subject.serializable_hash[:data][:attributes][:value]).to eq([1, 2, 3, 'test'])
    end
  end
end
