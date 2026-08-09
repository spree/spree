require 'spec_helper'

describe Spree::CustomFields::RichText, type: :model do
  let(:custom_field_definition) { create(:custom_field_definition, :rich_text_field) }
  let(:custom_field) { described_class.new(custom_field_definition: custom_field_definition, value: '<p>Rich text with <strong>formatting</strong></p>') }

  describe '#value' do
    it 'returns the rich text body' do
      expect(custom_field.value).to be_kind_of(ActionText::RichText)
    end
  end

  describe '#serialize_value' do
    it 'returns the rich text body' do
      expect(custom_field.serialize_value).to eq(custom_field.value.body.to_s)
    end
  end
end
