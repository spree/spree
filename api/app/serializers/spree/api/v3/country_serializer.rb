module Spree
  module Api
    module V3
      class CountrySerializer < BaseSerializer
        typelize_from Spree::Country

        attributes :id, :iso, :iso3, :iso_name, :name, :states_required, :zipcode_required

        many :states,
             resource: Spree.api.state_serializer,
             if: proc { params[:includes]&.include?('states') }
      end
    end
  end
end
