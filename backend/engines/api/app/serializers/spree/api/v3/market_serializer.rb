module Spree
  module Api
    module V3
      class MarketSerializer < BaseSerializer
        typelize name: :string, currency: :string,
                 default_locale: :string, supported_locales: 'string[]',
                 tax_inclusive: :boolean, default: :boolean,
                 countries: 'StoreCountry[]'

        attributes :name, :currency, :default_locale, :tax_inclusive, :default

        attribute :supported_locales do |market|
          market.supported_locales_list
        end

        attribute :countries do |market|
          market.countries.order(:name).map do |country|
            Spree.api.country_serializer.new(country, params: { includes: [] }).to_h
          end
        end
      end
    end
  end
end
