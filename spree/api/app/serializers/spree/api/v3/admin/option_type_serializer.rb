module Spree
  module Api
    module V3
      module Admin
        class OptionTypeSerializer < V3::OptionTypeSerializer
          typelize filterable: :boolean

          attributes :filterable

          has_many :option_values, serializer: Spree::Api::V3::Admin::OptionValueSerializer
        end
      end
    end
  end
end
