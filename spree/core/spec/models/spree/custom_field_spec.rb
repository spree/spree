require 'spec_helper'

RSpec.describe 'Spree::CustomField constant alias' do
  it 'aliases Spree::Metafield' do
    expect(Spree::CustomField).to equal(Spree::Metafield)
  end

  it 'lets the alias serve as a model entry point' do
    product = create(:product)
    definition = create(:metafield_definition, :short_text_field)

    cf = Spree::CustomField.new(
      resource: product,
      custom_field_definition_id: definition.id,
      value: 'wool'
    )
    expect(cf.save).to be(true)
    expect(Spree::CustomField.find(cf.id).value).to eq('wool')
  end
end
