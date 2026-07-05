require 'spec_helper'

describe Spree::Metafields::RichText, type: :model do
  let(:metafield_definition) { create(:metafield_definition, :rich_text_field) }
  let(:metafield) { described_class.new(metafield_definition: metafield_definition, value: '<p>Rich text with <strong>formatting</strong></p>') }

  describe '#value' do
    it 'returns the rich text body' do
      expect(metafield.value).to be_kind_of(ActionText::RichText)
    end
  end

  describe '#serialize_value' do
    it 'returns the rich text body' do
      expect(metafield.serialize_value).to eq(metafield.value.body.to_s)
    end
  end
end
