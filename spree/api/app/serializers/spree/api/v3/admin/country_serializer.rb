module Spree
  module Api
    module V3
      module Admin
        class CountrySerializer < V3::CountrySerializer
          many :states,
          resource: Spree.api.admin_state_serializer,
          if: proc { params[:expand]&.include?('states') }
        end
      end
    end
  end
end
