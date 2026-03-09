module Spree
  module Api
    module V3
      module Admin
        class OptionValueSerializer < V3::OptionValueSerializer
          one :option_type,
              resource: Spree.api.admin_option_type_serializer,
              if: proc { expand?('option_type') }
        end
      end
    end
  end
end
