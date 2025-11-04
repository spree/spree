module Spree
  module Api
    module V3
      class OptionValueSerializer < BaseSerializer
        def attributes
          {
            id: resource.id,
            name: resource.name,
            presentation: resource.presentation,
            position: resource.position,
            option_type_id: resource.option_type_id,
            option_type_name: resource.option_type.name
          }
        end
      end
    end
  end
end
