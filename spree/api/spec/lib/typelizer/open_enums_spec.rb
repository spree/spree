require 'spec_helper'

RSpec.describe Typelizer::OpenEnums::Property do
  def property(enum_type_name, enum)
    Typelizer::Property.new(name: :code, type: :string, enum: enum, enum_type_name: enum_type_name)
  end

  describe '#enum_definition' do
    it 're-exports an extensible list from sdk-core instead of copying it' do
      expect(property('ProductStatus', %w[draft active]).enum_definition)
        .to eq("type { ProductStatus } from '@spree/sdk-core'")
    end

    it 're-exports an ISO code list from sdk-core instead of copying it' do
      expect(property('CurrencyCode', %w[EUR USD]).enum_definition)
        .to eq("type { CurrencyCode } from '@spree/sdk-core'")
    end

    it 'leaves a property without a named list alone' do
      expect(property(nil, %w[a b]).enum_definition).to be_nil
    end
  end

  describe '#fingerprint' do
    it 'changes with the re-export for a named list, so files written before it regenerate' do
      named = property('CountryCode', %w[DE US])
      inline = Typelizer::Property.new(**named.to_h, enum_type_name: nil)

      expect(named.fingerprint).to include("from '@spree/sdk-core'")
      expect(inline.fingerprint).not_to include('sdk-core')
    end
  end
end
