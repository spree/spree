module Spree
  module Api
    module V3
      # A custom field value written inline with its owner (product, category, seller…).
      class CustomFieldValueRequestSchema < Spree::Api::V3::RequestSchema
        publishes 'CustomFieldValueParams'

        attribute :id, :id
        attribute :custom_field_definition_id, :id
        attribute :value, :any,
          description: 'A scalar for text, number and boolean fields; a list or a hash for JSON fields.'
      end
    end
  end
end
