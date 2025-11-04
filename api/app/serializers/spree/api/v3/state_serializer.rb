module Spree
  module Api
    module V3
      class StateSerializer < BaseSerializer
        def attributes
          {
            id: resource.id,
            name: resource.name,
            abbr: resource.abbr,
            country_id: resource.country_id
          }
        end
      end
    end
  end
end
