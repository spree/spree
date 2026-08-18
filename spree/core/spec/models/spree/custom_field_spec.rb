require 'spec_helper'

RSpec.describe Spree::CustomField, type: :model do
  context 'Callbacks' do
    it 'sets the type from the custom_field definition' do
      custom_field_definition = create(:custom_field_definition, field_type: 'Spree::CustomFields::ShortText')
      custom_field = create(:custom_field, custom_field_definition: custom_field_definition, type: nil)
      expect(custom_field.type).to eq('Spree::CustomFields::ShortText')
    end
  end

  context 'Validations' do
    it 'validates the type must match the custom_field definition' do
      custom_field_definition = create(:custom_field_definition, field_type: 'Spree::CustomFields::ShortText')
      custom_field = build(:custom_field, custom_field_definition: custom_field_definition, type: 'Spree::CustomFields::LongText')
      expect(custom_field.valid?).to be false
    end
  end

  context 'Scopes' do
    describe '.with_key' do
      it 'returns the custom_fields with the given key' do
        custom_field_definition = create(:custom_field_definition, namespace: 'custom', key: 'foo')
        custom_field = create(:custom_field, custom_field_definition: custom_field_definition)
        other_definition = create(:custom_field_definition, namespace: 'custom', key: 'bar')
        create(:custom_field, custom_field_definition: other_definition)
        expect(described_class.with_key('custom', 'foo').ids).to contain_exactly(custom_field.id)
      end
    end
  end

  describe '#serialize_value' do
    it 'returns the value' do
      custom_field = build(:custom_field, value: 'Test Value')
      expect(custom_field.serialize_value).to eq('Test Value')
    end
  end

  describe '#csv_value' do
    context 'for base CustomField' do
      it 'returns the value as string' do
        custom_field = build(:custom_field, value: 'Test Value')
        expect(custom_field.csv_value).to eq('Test Value')
      end
    end

    context 'for Boolean custom_field' do
      let(:custom_field_definition) { create(:custom_field_definition, field_type: 'Spree::CustomFields::Boolean') }

      it 'returns Yes for true values' do
        custom_field = Spree::CustomFields::Boolean.new(custom_field_definition: custom_field_definition, value: 'true')
        expect(custom_field.csv_value).to eq(Spree.t(:say_yes))
      end

      it 'returns No for false values' do
        custom_field = Spree::CustomFields::Boolean.new(custom_field_definition: custom_field_definition, value: 'false')
        expect(custom_field.csv_value).to eq(Spree.t(:say_no))
      end
    end

    context 'for Number custom_field' do
      let(:custom_field_definition) { create(:custom_field_definition, field_type: 'Spree::CustomFields::Number') }

      it 'returns the number as string' do
        custom_field = Spree::CustomFields::Number.new(custom_field_definition: custom_field_definition, value: '123.45')
        expect(custom_field.csv_value).to eq('123.45')
      end
    end

    context 'for Json custom_field' do
      let(:custom_field_definition) { create(:custom_field_definition, field_type: 'Spree::CustomFields::Json') }

      it 'returns the JSON string' do
        custom_field = Spree::CustomFields::Json.new(custom_field_definition: custom_field_definition, value: '{"key": "value"}')
        expect(custom_field.csv_value).to eq('{"key": "value"}')
      end
    end

    context 'for ShortText custom_field' do
      let(:custom_field_definition) { create(:custom_field_definition, field_type: 'Spree::CustomFields::ShortText') }

      it 'returns the text value' do
        custom_field = Spree::CustomFields::ShortText.new(custom_field_definition: custom_field_definition, value: 'Short text')
        expect(custom_field.csv_value).to eq('Short text')
      end
    end

    context 'for LongText custom_field' do
      let(:custom_field_definition) { create(:custom_field_definition, field_type: 'Spree::CustomFields::LongText') }

      it 'returns the text value' do
        custom_field = Spree::CustomFields::LongText.new(custom_field_definition: custom_field_definition, value: 'Long text content')
        expect(custom_field.csv_value).to eq('Long text content')
      end
    end

    context 'for RichText custom_field' do
      let(:custom_field_definition) { create(:custom_field_definition, field_type: 'Spree::CustomFields::RichText') }

      it 'returns plain text without HTML tags' do
        custom_field = Spree::CustomFields::RichText.new(custom_field_definition: custom_field_definition)
        custom_field.value = '<p>Rich <strong>text</strong> content</p>'
        expect(custom_field.csv_value).to eq('Rich text content')
      end
    end
  end

  describe 'resource type validation' do
    let(:product) { create(:product) }

    it 'rejects a definition belonging to another resource type' do
      variant_definition = create(:custom_field_definition, :for_variant)
      custom_field = build(:custom_field, resource: product, custom_field_definition: variant_definition)

      expect(custom_field).not_to be_valid
      expect(custom_field.errors[:resource_type]).to be_present
    end

    it 'accepts a definition naming an STI subclass of the resource' do
      # An STI row stores its base class in the polymorphic column while the
      # definition names the subclass, so the two still have to match up.
      subclass = Class.new(Spree::Variant) do
        def self.name = 'Spree::TestVariantSubclass'
      end
      stub_const('Spree::TestVariantSubclass', subclass)
      allow(Spree::CustomFieldDefinition).to receive(:available_resources).
        and_return(Spree::CustomFieldDefinition.available_resources + [subclass])

      definition = create(:custom_field_definition, resource_type: 'Spree::TestVariantSubclass', key: 'sti_key')
      custom_field = build(:custom_field, custom_field_definition: definition, value: 'x')
      custom_field.resource_type = 'Spree::Variant'

      custom_field.valid?
      expect(custom_field.errors[:resource_type]).to be_empty
    end
  end

  describe 'deprecated definition writer' do
    it 'assigns through metafield_definition=' do
      definition = create(:custom_field_definition)
      custom_field = Spree::CustomField.new
      custom_field.metafield_definition = definition

      expect(custom_field.custom_field_definition).to eq(definition)
    end
  end
end
