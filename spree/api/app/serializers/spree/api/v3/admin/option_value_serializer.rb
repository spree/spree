module Spree
  module Api
    module V3
      module Admin
        class OptionValueSerializer < V3::OptionValueSerializer
          attributes created_at: :iso8601, updated_at: :iso8601

          one :option_type,
              resource: Spree.api.admin_option_type_serializer,
              if: proc { expand?('option_type') }

          many :metafields,
               resource: Spree.api.admin_metafield_serializer,
               if: proc { expand?('metafields') }
        end
      end
    end
  end
end
