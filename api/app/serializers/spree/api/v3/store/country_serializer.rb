module Spree
  module Api
    module V3
      module Store
        class CountrySerializer < BaseSerializer
          attributes :id, :iso, :iso3, :iso_name, :name, :states_required, :zipcode_required

          many :states,
              resource: Spree.api.v3_store_state_serializer,
              if: proc { params[:includes]&.include?('states') }
        end
      end
    end
  end
end
