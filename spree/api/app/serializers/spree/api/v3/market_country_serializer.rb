module Spree
  module Api
    module V3
      # Lightweight country serializer for use when nested inside MarketSerializer.
      # Omits market-derived fields (currency, locale) since the parent market already has them.
      class MarketCountrySerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize iso: :string, iso3: :string, name: :string,
                 states_required: :boolean, zipcode_required: :boolean

        attributes :iso, :iso3, :name, :states_required, :zipcode_required

        many :states,
             resource: Spree.api.state_serializer,
             if: proc { params[:includes]&.include?('states') }
      end
    end
  end
end
