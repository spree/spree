module Spree
  module Api
    module V3
      module Admin
        # No timestamps — see Admin::CountrySerializer.
        class StateSerializer < V3::StateSerializer
        end
      end
    end
  end
end
