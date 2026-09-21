module Spree
  module Api
    module V3
      class MarketSerializer < BaseSerializer
        typelize name: :string, currency: :string,
                 default_locale: :string,
                 supported_locales: [:string, multi: true],
                 country_codes: [:string, multi: true],
                 country_isos: [:string, multi: true],
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
