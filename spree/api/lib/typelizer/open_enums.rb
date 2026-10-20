module Typelizer
  # A `typelize` entry with `enum:` alone is a closed list — the right shape
  # for values nothing outside core can grow (units, match policies). Adding
  # `enum_type_name:` marks the list as one an extension may extend
  # (`has_status` values, `Spree::Fee::KINDS`), and both generated contracts
  # follow suit: the TypeScript type becomes a named, exported union that stays
  # open, and the OpenAPI property becomes an open enum, so a client generated
  # from either still accepts an added value while every built-in value stays
  # documented and autocompletable.
  #
  # Shared code lists are the exception: a named type several serializers and
  # the request types share, but closed, since nothing outside the standard
  # can add a country, a currency or a unit, and markets only accept the
  # locales `Spree::Locales::ALL` lists. The SDKs define them once, as values
  # and types, in `@spree/sdk-core` (generated from the API reference by
  # `pnpm generate:code-lists`), so each SDK's `Enums.ts` re-exports that
  # definition instead of carrying a copy of the list.
  module OpenEnums
    CLOSED_TYPE_NAMES = %w[CountryCode CurrencyCode LocaleCode WeightUnit DimensionUnit].freeze

    module Property
      def enum_definition(...)
        definition = super
        return definition unless definition
        return "type { #{enum_type_name} } from '@spree/sdk-core'" if CLOSED_TYPE_NAMES.include?(enum_type_name)

        "#{definition} | (string & {})"
      end

      # Typelizer skips rewriting a file whose digest is unchanged, and the
      # digest covers a property's values but not the definition above. Folding
      # the re-export in makes a checkout that still carries the old inline
      # list regenerate.
      def fingerprint
        return super unless CLOSED_TYPE_NAMES.include?(enum_type_name)

        [super, enum_definition].inspect
      end
    end

    module Schema
      OPEN_ENUM_DESCRIPTION = 'The values listed are the built-in ones; extensions may add more.'.freeze

      def inline_schema(definition, property, openapi_version:)
        return super unless property.enum_type_name && property.enum.is_a?(Array) && !property.multi
        return super if CLOSED_TYPE_NAMES.include?(property.enum_type_name)

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
