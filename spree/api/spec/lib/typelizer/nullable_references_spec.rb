require 'spec_helper'
require 'spree/api/openapi/schema_helper'

RSpec.describe Typelizer::NullableReferences do
  def schema(openapi_version: '3.0.3', **attributes)
    property = Typelizer::Property.new(name: :pickup_location, type: 'StockLocation', **attributes)
    Typelizer::OpenAPI.property_schema(property, openapi_version: openapi_version)
  end

  let(:reference) { { '$ref' => '#/components/schemas/StockLocation' } }
  let(:null_branch) { { type: :object, nullable: true, enum: [nil] } }

  it 'lets a nullable reference accept null where OpenAPI 3.0 reads it' do
    expect(schema(nullable: true, comment: 'Where to collect it')).
      to eq(anyOf: [reference, null_branch], description: 'Where to collect it')
  end

  it 'leaves a reference that is never null alone' do
    expect(schema).to eq(reference)
  end

  it 'leaves OpenAPI 3.1, which spells null as a type, alone' do
    expect(schema(openapi_version: '3.1', nullable: true)).to eq(oneOf: [reference, { type: :null }])
  end

  it 'publishes the nullable calculators the same way' do
    schemas = Spree::Api::OpenAPI::SchemaHelper.admin_schemas
    calculators = [schemas.dig('DeliveryMethod', :properties, 'calculator') || schemas.dig(:DeliveryMethod, :properties, :calculator),
                   schemas.dig('PromotionAction', :properties, 'calculator') || schemas.dig(:PromotionAction, :properties, :calculator)]

    expect(calculators).to all(include(anyOf: [hash_including('$ref'), null_branch]))
  end
end
