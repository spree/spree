module Spree
  module Api
    module V3
      module Seller
        class RequirementCustomFieldSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize id: :string, key: :string, label: :string,
                   field_type: Spree::CustomField::FIELD_TYPE_TOKENS,
                   value: :any

          attribute :id do |pair|
            pair[:definition].prefixed_id
          end

          attribute :key do |pair|
            pair[:definition].full_key
          end

          attribute :label do |pair|
            pair[:definition].label
          end

          attribute :field_type do |pair|
            pair[:definition].field_type
          end

          attribute :value do |pair|
            pair[:custom_field]&.serialize_value
          end
        end
      end
    end
  end
end
