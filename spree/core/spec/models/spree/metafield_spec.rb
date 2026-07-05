require 'spec_helper'

RSpec.describe Spree::Metafield, type: :model do
  context 'Callbacks' do
    it 'sets the type from the metafield definition' do
      metafield_definition = create(:metafield_definition, metafield_type: 'Spree::Metafields::ShortText')
      metafield = create(:metafield, metafield_definition: metafield_definition, type: nil)
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

  describe '#csv_value' do
    context 'for base Metafield' do
      it 'returns the value as string' do
        metafield = build(:metafield, value: 'Test Value')
        expect(metafield.csv_value).to eq('Test Value')
      end
    end

    context 'for Boolean metafield' do
      let(:metafield_definition) { create(:metafield_definition, metafield_type: 'Spree::Metafields::Boolean') }

      it 'returns Yes for true values' do
        metafield = Spree::Metafields::Boolean.new(metafield_definition: metafield_definition, value: 'true')
        expect(metafield.csv_value).to eq(Spree.t(:say_yes))
      end

      it 'returns No for false values' do
        metafield = Spree::Metafields::Boolean.new(metafield_definition: metafield_definition, value: 'false')
        expect(metafield.csv_value).to eq(Spree.t(:say_no))
      end
    end

    context 'for Number metafield' do
      let(:metafield_definition) { create(:metafield_definition, metafield_type: 'Spree::Metafields::Number') }

      it 'returns the number as string' do
        metafield = Spree::Metafields::Number.new(metafield_definition: metafield_definition, value: '123.45')
        expect(metafield.csv_value).to eq('123.45')
      end
    end

    context 'for Json metafield' do
      let(:metafield_definition) { create(:metafield_definition, metafield_type: 'Spree::Metafields::Json') }

      it 'returns the JSON string' do
        metafield = Spree::Metafields::Json.new(metafield_definition: metafield_definition, value: '{"key": "value"}')
        expect(metafield.csv_value).to eq('{"key": "value"}')
      end
    end

    context 'for ShortText metafield' do
      let(:metafield_definition) { create(:metafield_definition, metafield_type: 'Spree::Metafields::ShortText') }

      it 'returns the text value' do
        metafield = Spree::Metafields::ShortText.new(metafield_definition: metafield_definition, value: 'Short text')
        expect(metafield.csv_value).to eq('Short text')
      end
    end

    context 'for LongText metafield' do
      let(:metafield_definition) { create(:metafield_definition, metafield_type: 'Spree::Metafields::LongText') }

      it 'returns the text value' do
        metafield = Spree::Metafields::LongText.new(metafield_definition: metafield_definition, value: 'Long text content')
        expect(metafield.csv_value).to eq('Long text content')
      end
    end

    context 'for RichText metafield' do
      let(:metafield_definition) { create(:metafield_definition, metafield_type: 'Spree::Metafields::RichText') }

      it 'returns plain text without HTML tags' do
        metafield = Spree::Metafields::RichText.new(metafield_definition: metafield_definition)
        metafield.value = '<p>Rich <strong>text</strong> content</p>'
        expect(metafield.csv_value).to eq('Rich text content')
      end
    end
  end
end
