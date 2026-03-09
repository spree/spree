module Spree
  module Api
    module V3
      module Admin
        class OptionTypeSerializer < V3::OptionTypeSerializer
          many :option_values,
               resource: Spree.api.admin_option_value_serializer,
               if: proc { expand?('option_values') }
        end
      end
    end
  end
end
