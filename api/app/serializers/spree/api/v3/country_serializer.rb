module Spree
  module Api
    module V3
      class CountrySerializer < BaseSerializer
        attributes :id, :iso, :iso3, :iso_name, :name, :states_required, :zipcode_required

        many :states,
             resource: Spree.api.v3_storefront_state_serializer,
             if: proc { params[:includes]&.include?('states') }
      end
    end
  end
end
