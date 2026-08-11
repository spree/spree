require 'spec_helper'

describe Spree::CustomFields::RichText, type: :model do
  let(:custom_field_definition) { create(:custom_field_definition, :rich_text_field) }
  let(:product) { create(:product) }
  let(:custom_field) do
    described_class.new(resource: product, custom_field_definition: custom_field_definition,
                        value: '<p>Rich text with <strong>formatting</strong></p>')
  end

  describe '#value' do
    it 'stores HTML in the shared value column' do
      expect(custom_field.value).to eq('<p>Rich text with <strong>formatting</strong></p>')
    end
  end

  describe '#serialize_value' do
    it 'returns the stored HTML' do
      expect(custom_field.serialize_value).to eq('<p>Rich text with <strong>formatting</strong></p>')
    end
  end

  describe '#csv_value' do
    it 'strips the markup' do
      expect(custom_field.csv_value).to eq('Rich text with formatting')
    end

    it 'returns an empty string when there is no value' do
      custom_field.value = nil
      expect(custom_field.csv_value).to eq('')
    end
  end

  describe 'sanitization' do
    it 'strips dangerous markup on save' do
      custom_field.value = '<p>ok</p><script>alert(1)</script>'
      custom_field.save!

      expect(custom_field.reload.value).to include('<p>ok</p>')
      expect(custom_field.value).not_to include('<script>')
    end
  end
end
