module Spree
  module Api
    module V3
      # A custom field value written inline with its owner (product, category, seller…).
      class CustomFieldValueRequestSchema < Spree::Api::V3::RequestSchema
        publishes 'CustomFieldValueParams'

        id :id
        id :custom_field_definition_id
        any :value, description: 'A scalar for text, number and boolean fields; a list or a hash for JSON fields.'
      end
    end
  end
end
