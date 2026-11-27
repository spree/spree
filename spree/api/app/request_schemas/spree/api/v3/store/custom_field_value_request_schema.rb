module Spree
  module Api
    module V3
      module Store
        # A value a shopper fills in, named by the field's key. Used by carts
        # (order fields) and customers (account fields).
        class CustomFieldValueRequestSchema < Spree::Api::V3::RequestSchema
          publishes 'CustomFieldEntryParams'

          attribute :key, :string, required: true, example: 'checkout.delivery_date',
                                   description: 'The field as `namespace.key`, from `GET /store/custom_field_definitions`.'
          attribute :value, :any, example: '2026-10-12', description: <<~TEXT.squish
            A string for text, date and single choice fields (date-times in ISO 8601), a decimal string for number
            fields, true or false for boolean fields, and a list of values for a choice field that allows several.
            Blank removes the value.
          TEXT
        end
      end
    end
  end
end
