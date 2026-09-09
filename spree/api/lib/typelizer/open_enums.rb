module Typelizer
  # A `typelize` entry with `enum:` alone is a closed list — the right shape
  # for values nothing outside core can grow (units, match policies). Adding
  # `enum_type_name:` marks the list as one an extension may extend
  # (`has_status` values, `Spree::Fee::KINDS`), and both generated contracts
  # follow suit: the TypeScript type becomes a named, exported union that stays
  # open, and the OpenAPI property becomes an open enum, so a client generated
  # from either still accepts an added value while every built-in value stays
  # documented and autocompletable.
  module OpenEnums
    module Property
      def enum_definition(...)
        definition = super
        definition && "#{definition} | (string & {})"
      end
    end

    module Schema
      OPEN_ENUM_DESCRIPTION = 'The values listed are the built-in ones; extensions may add more.'.freeze

      def inline_schema(definition, property, openapi_version:)
        return super unless property.enum_type_name && property.enum.is_a?(Array) && !property.multi

        open = { anyOf: [{ type: :string, enum: property.enum.compact }, { type: :string }] }
        apply_nullable(open, property, openapi_version: openapi_version)
        apply_metadata(open, property)
        open[:description] ||= OPEN_ENUM_DESCRIPTION
        open
      end
    end
  end
end

Typelizer::Property.prepend(Typelizer::OpenEnums::Property)
Typelizer::OpenAPI.singleton_class.prepend(Typelizer::OpenEnums::Schema)
