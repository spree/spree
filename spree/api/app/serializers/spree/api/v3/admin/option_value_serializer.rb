module Spree
  module Api
    module V3
      module Admin
        class OptionValueSerializer < V3::OptionValueSerializer
          typelize metadata: 'Record<string, unknown>'

          attributes :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          expandable :one, :option_type, :admin_option_type_serializer
        end
      end
    end
  end
end
