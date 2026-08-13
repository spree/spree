module Spree
  module Api
    module V3
      module Admin
        # No timestamps: countries are reference data supplied by the countries
        # gem rather than records, so they have no created_at/updated_at.
        class CountrySerializer < V3::CountrySerializer
          many :states,
               resource: proc { Spree.api.admin_state_serializer },
               if: proc { params[:expand]&.include?('states') }
        end
      end
    end
  end
end
