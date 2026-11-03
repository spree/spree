module Spree
  module Api
    module V3
      module Admin
        # One option of a `choice` custom field: the stored `value` and the
        # `label` shown for it.
        class CustomFieldChoiceSerializer < BaseSerializer
          _attributes.delete(:id)

          typelize value: :string, label: :string

          attribute :value do |choice|
            choice['value']
          end
          attribute :label do |choice|
            choice['label']
          end
        end
      end
    end
  end
end
