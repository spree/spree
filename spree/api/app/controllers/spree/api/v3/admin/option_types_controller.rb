module Spree
  module Api
    module V3
      module Admin
        class OptionTypesController < ResourceController
          scoped_resource :products

          request_params :option_type do |body|
            body.attribute :name, :string, required: true, on: :create, example: 'color'
            body.attribute :label, :string, required: true, on: :create, example: 'Color'
            body.attribute :position, :integer
            body.attribute :filterable, :boolean
            body.attribute :kind, :string, choices: Spree::OptionType::KINDS
            body.attribute :option_values, :array,
              as: 'OptionValueParams',
              description: 'Inline option values. Values left out of the list on update are destroyed, so send the full set every time.' do |option_value|
              option_value.attribute :id, :id, description: 'Present for existing values. Omit to create a new one.'
              option_value.attribute :name, :string, example: 'red'
              option_value.attribute :label, :string, example: 'Red'
              option_value.attribute :position, :integer
              option_value.attribute :color_code, :string,
                nullable: true,
                example: '#FF0000',
                description: "Hex color. Only meaningful when the option type's `kind` is `color_swatch`."
              option_value.attribute :image_signed_id, :string,
                nullable: true,
                description: 'A `signed_id` from `files.upload()`, or null to remove the image.'
            end
          end

          protected

          def model_class
            Spree::OptionType
          end

          def serializer_class
            Spree.api.admin_option_type_serializer
          end

          def scope_includes
            [:option_values]
          end

          def permitted_params
            params.permit(*permitted_attributes)
          end
        end
      end
    end
  end
end
