module Spree
  module Api
    module V3
      module Admin
        class OptionTypeSerializer < V3::OptionTypeSerializer
          include Spree::Api::V3::Admin::Translatable

          typelize metadata: 'Record<string, unknown>', filterable: :boolean

          attributes :metadata, :filterable,
                     created_at: :iso8601, updated_at: :iso8601

          many :option_values,
               resource: Spree.api.admin_option_value_serializer,
               if: proc { expand?('option_values') }
        end
      end
    end
  end
end
