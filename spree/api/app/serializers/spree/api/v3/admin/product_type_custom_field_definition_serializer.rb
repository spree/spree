module Spree
  module Api
    module V3
      module Admin
        # A custom field definition as used by one product type: the definition's
        # own schema fields, plus how this type uses it (required, sort order).
        #
        # `id` is the definition's prefixed id (`cfdef_…`), not the join row's —
        # that is what clients send back on PATCH.
        class ProductTypeCustomFieldDefinitionSerializer < BaseSerializer
          typelize id: :string,
                   key: :string,
                   namespace: :string,
                   label: :string,
                   field_type: Spree::Metafield::FIELD_TYPE_TOKENS,
                   required: :boolean,
                   sort_order: :number

          attribute :id do |join|
            join.custom_field_definition.prefixed_id
          end

          attribute :key do |join|
            join.custom_field_definition.key
          end

          attribute :namespace do |join|
            join.custom_field_definition.namespace
          end

          attribute :label do |join|
            join.custom_field_definition.label
          end

          attribute :field_type do |join|
            join.custom_field_definition.field_type
          end

          attributes :required, :sort_order
        end
      end
    end
  end
end
