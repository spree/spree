module Spree
  module Api
    module V3
      class CountrySerializer
        include Alba::Resource
        include Typelizer::DSL

        # ISO 3166-1 codes - iso is the identifier, no redundant id field
        typelize iso: :string, iso3: :string, name: :string,
                 states_required: :boolean, zipcode_required: :boolean,
                 currency: [:string, nullable: true],
                 default_locale: [:string, nullable: true],
                 supported_locales: [:string, multi: true]

        attributes :iso, :iso3, :name, :states_required, :zipcode_required

        attribute :currency do |country|
          country.market_currency
        end

        attribute :default_locale do |country|
          country.market_locale
        end

        attribute :supported_locales do |country|
          country.market_supported_locales
        end

        many :states,
             resource: Spree.api.state_serializer,
             if: proc { params[:includes]&.include?('states') }
      end
    end
  end
end
