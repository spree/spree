module Spree
  module Api
    module V3
      module Admin
        class OptionValueSerializer < V3::OptionValueSerializer
          typelize metadata: 'Record<string, unknown>'

          attributes :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          one :option_type,
              resource: proc { Spree.api.admin_option_type_serializer },
              if: proc { expand?('option_type') }
        end
      end
    end
  end
end
