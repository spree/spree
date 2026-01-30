module Spree
  module Api
    module V3
      class CountrySerializer
        include Alba::Resource
        include Typelizer::DSL

        # ISO 3166-1 codes - iso is the identifier, no redundant id field
        typelize iso: :string, iso3: :string, name: :string,
                 states_required: :boolean, zipcode_required: :boolean,
                 default_currency: 'string | null', default_locale: 'string | null'

        attributes :iso, :iso3, :name, :states_required, :zipcode_required,
                   :default_currency, :default_locale

        many :states,
             resource: Spree.api.state_serializer,
             if: proc { params[:includes]&.include?('states') }
      end
    end
  end
end
