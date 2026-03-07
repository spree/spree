module Spree
  module Api
    module V3
      module Admin
        class OptionTypeSerializer < V3::OptionTypeSerializer
          typelize filterable: :boolean

          attributes :filterable,
                     created_at: :iso8601, updated_at: :iso8601

          has_many :option_values, serializer: Spree::Api::V3::Admin::OptionValueSerializer

          many :metafields,
               resource: Spree.api.admin_metafield_serializer,
               if: proc { expand?('metafields') }
        end
      end
    end
  end
end
