module Spree
  module Api
    module V3
      module Admin
        class OptionTypeSerializer < V3::OptionTypeSerializer
          include Spree::Api::V3::Admin::Translatable

          typelize metadata: 'Record<string, unknown>', filterable: :boolean

          attributes :metadata, :filterable,
                     created_at: :iso8601, updated_at: :iso8601

          expandable :many, :option_values, :admin_option_value_serializer
        end
      end
    end
  end
end
