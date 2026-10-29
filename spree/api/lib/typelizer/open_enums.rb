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
  # Every named list is defined once, as values and type, in `@spree/core`, and
  # each SDK's `Enums.ts` re-exports it through `@spree/sdk-core` instead of
  # carrying a copy. {Spree::Api::EnumTypes} writes them there.
  #
  # A name in `CLOSED_LIST_NAMES` keeps its list closed — named only so it is
  # defined once — and both contracts stay exactly what `enum:` alone gives.
  # Shared code lists are closed too, but come from the API reference
  # (`pnpm generate:code-lists`) rather than the serializers: nothing outside
  # the standard can add a country, a currency or a unit, and markets only
  # accept the locales `Spree::Locales::ALL` lists.
  module OpenEnums
    CLOSED_TYPE_NAMES = %w[CountryCode CurrencyCode LocaleCode WeightUnit DimensionUnit].freeze

    CLOSED_LIST_NAMES = %w[
      ApiKeyType CaptureMethod CatalogAssignableType CatalogPriceSource ClaimResolution
      CollectionRuleMatchPolicy CollectionSortOrder CommissionKind CompanyInvitationStatus CompanyKind
      ConsentSource DataRequestKind DeliveryStatus DeliveryZoneMemberType DiscountKind DocumentNumberFormat
      EmailFont EmailTemplateKind FileUploadVisibility FulfillmentType MatchPolicy MediaType OptionTypeKind
      OrderFulfillmentStatus OrderPaymentStatus OrderStatus PackageTypeKind PaymentSourceType
      PayoutScheduleInterval PermissionKind PickupStockPolicy ProviderFailurePolicy PurchaseUnit
      SellerRequirementState SellerTransferKind ShippingLabelFormat ShippingLabelOwnerType ShippingLabelSource
      StockAvailability StockMovementKind StockReceiptLineType StockReceiptReceivableType
      StockReceiptRejectionReason StorefrontAccess TaxIdentifierSource TaxIdentifierValidationStatus
      TaxRemittance UnitSystem
    ].freeze

    # Open lists whose values are suggestions rather than built-ins an
    # extension adds to, described as such wherever the list is published.
    DESCRIPTIONS = {
      'TimeZone' => 'Common IANA time zones; any other IANA time zone identifier is accepted too.'
    }.freeze

    # @param name [String, nil] a list's `enum_type_name`
    # @return [String, nil] what the list's values are, when they are not built-ins
    def self.description(name)
      DESCRIPTIONS[name]
    end

    # @param schema [Hash] the schema of any value in the list
    # @param values [Array<String>] the values to suggest
    # @return [Hash] a schema suggesting the values while accepting any other
    def self.open_schema(schema, values)
      { anyOf: [schema.merge(enum: values), schema] }
    end

    # @param name [String, nil] a list's `enum_type_name`
    # @return [Boolean] whether the list is closed: no value outside it is valid
    def self.closed?(name)
      CLOSED_TYPE_NAMES.include?(name) || CLOSED_LIST_NAMES.include?(name)
    end

    module Property
      def enum_definition(...)
        super && "type { #{enum_type_name} } from '@spree/sdk-core'"
      end

      # Typelizer skips rewriting a file whose digest is unchanged, and the
      # digest covers a property's values but not the definition above. Folding
      # the re-export in makes a checkout that still carries the old inline
      # list regenerate.
      def fingerprint
        return super unless enum_type_name

        [super, enum_definition].inspect
      end
    end

    module Schema
      OPEN_ENUM_DESCRIPTION = 'The values listed are the built-in ones; extensions may add more.'.freeze

      def inline_schema(definition, property, openapi_version:)
        return super unless property.enum_type_name && property.enum.is_a?(Array) && !property.multi
        return super if OpenEnums.closed?(property.enum_type_name)

        open = OpenEnums.open_schema({ type: :string }, property.enum.compact)
        # OpenAPI 3.0 ignores `nullable` beside `anyOf`, which is where
        # Typelizer puts it, so the free-string branch carries it instead.
        if property.nullable && !v31?(openapi_version)
          open[:anyOf].last[:nullable] = true
        else
          apply_nullable(open, property, openapi_version: openapi_version)
        end
        apply_metadata(open, property)
        open[:description] ||= OpenEnums.description(property.enum_type_name) || OPEN_ENUM_DESCRIPTION
        open
      end
    end
  end
end

Typelizer::Property.prepend(Typelizer::OpenEnums::Property)
Typelizer::OpenAPI.singleton_class.prepend(Typelizer::OpenEnums::Schema)
