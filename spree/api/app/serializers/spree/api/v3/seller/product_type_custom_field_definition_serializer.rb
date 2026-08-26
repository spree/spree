module Spree
  module Api
    module V3
      module Seller
        # The schema of one custom field a product type asks for.
        #
        # Declared rather than subclassed from the admin serializer, like every
        # serializer on this branch: what a seller needs is the shape of the
        # field they are filling in, and inheriting would tie this branch's
        # generated types to the operator's.
        class ProductTypeCustomFieldDefinitionSerializer < V3::BaseSerializer
          typelize id: :string,
                   key: :string,
                   namespace: :string,
                   label: :string,
                   field_type: Spree::CustomField::FIELD_TYPE_TOKENS,
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
