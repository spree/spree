module Spree
  module Api
    module V3
      module Seller
        # One custom field value a seller filled in.
        class CustomFieldSerializer < V3::CustomFieldSerializer
          typelize custom_field_definition_id: [:string, nullable: true]

          attribute :custom_field_definition_id do |custom_field|
            custom_field.custom_field_definition&.prefixed_id
          end
        end
      end
    end
  end
end
