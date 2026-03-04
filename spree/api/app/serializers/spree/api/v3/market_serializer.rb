module Spree
  module Api
    module V3
      class MarketSerializer < BaseSerializer
        typelize name: :string, currency: :string,
                 default_locale: :string,
                 supported_locales: [:string, multi: true],
                 tax_inclusive: :boolean,
                 default: :boolean

        attributes :name, :currency, :default_locale, :tax_inclusive, :default

        attribute :supported_locales do |market|
          market.supported_locales_list
        end

        many :countries,
             resource: Spree.api.country_serializer,
             if: proc { expand?(:countries) }
      end
    end
  end
end
