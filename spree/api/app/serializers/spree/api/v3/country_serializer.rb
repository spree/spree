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
          market_for(country)&.currency
        end

        attribute :default_locale do |country|
          market_for(country)&.default_locale
        end

        attribute :supported_locales do |country|
          market_for(country)&.supported_locales_list || []
        end

        def market_for(country)
          params[:market_by_country_id]&.[](country.id)
        end

        many :states,
             resource: Spree.api.state_serializer,
             if: proc { params[:includes]&.include?('states') }
      end
    end
  end
end
