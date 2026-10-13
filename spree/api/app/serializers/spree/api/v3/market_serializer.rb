module Spree
  module Api
    module V3
      class MarketSerializer < BaseSerializer
        typelize name: :string, currency: [:string, enum: Spree::Money::Rounding::CURRENCY_CODES, enum_type_name: 'CurrencyCode'],
                 default_locale: [:string, enum: Spree::Locales::ALL, enum_type_name: 'LocaleCode'],
                 supported_locales: [:string, multi: true, enum: Spree::Locales::ALL, enum_type_name: 'LocaleCode'],
                 country_codes: [:string, multi: true, enum: Spree::IsoData.country_codes, enum_type_name: 'CountryCode'],
                 country_isos: [:string, multi: true, deprecated: 'Use `country_codes`. Removed in 6.1.'],
                 tax_inclusive: :boolean,
                 default: :boolean

        attributes :name, :currency, :default_locale, :tax_inclusive, :default, :country_codes

        # @deprecated Storefronts shipped against this name; use +country_codes+.
        #   Removed in 6.1.
        attribute :country_isos, &:country_codes

        attribute :supported_locales do |market|
          market.supported_locales_list
        end

        many :countries,
             resource: proc { Spree.api.country_serializer },
             if: proc { expand?(:countries) }
      end
    end
  end
end
