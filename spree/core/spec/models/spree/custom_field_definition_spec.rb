require 'spec_helper'

RSpec.describe 'Spree::CustomFieldDefinition constant alias' do
  it 'aliases Spree::MetafieldDefinition' do
    expect(Spree::CustomFieldDefinition).to equal(Spree::MetafieldDefinition)
  end

  it 'lets the alias serve as a model entry point' do
    defn = Spree::CustomFieldDefinition.new(
      namespace: 'specs',
      key: 'fabric',
      label: 'Fabric',
      field_type: 'Spree::Metafields::ShortText',
      resource_type: 'Spree::Product'
    )
    expect(defn).to be_valid
  end

  describe 'field_type input validation' do
    let(:base_attrs) do
      { namespace: 'specs', key: 'fabric', label: 'Fabric', resource_type: 'Spree::Product' }
    end

    it 'accepts the token form' do
      defn = Spree::CustomFieldDefinition.new(base_attrs.merge(field_type: 'short_text'))
      expect(defn).to be_valid
      expect(defn.field_type).to eq('short_text')
    end

    it 'accepts the legacy class-name form' do
      defn = Spree::CustomFieldDefinition.new(base_attrs.merge(field_type: 'Spree::Metafields::ShortText'))
      expect(defn).to be_valid
      expect(defn.field_type).to eq('short_text')
    end

    it 'reports an error on `field_type` with the token vocabulary for typo input' do
      defn = Spree::CustomFieldDefinition.new(base_attrs.merge(field_type: 'shrt_text'))
      expect(defn).not_to be_valid
      expect(defn.errors[:field_type]).to include(a_string_matching(/short_text.*long_text/))
    end
  end
end
