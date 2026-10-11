module Spree
  module Api
    module V3
      module Admin
        class OptionTypesController < ResourceController
          scoped_resource :products

          request_params :option_type do
            string :name, required: :create, example: 'color'
            string :label, required: :create, example: 'Color'
            integer :position
            boolean :filterable
            string :kind, enum: Spree::OptionType::KINDS
            object :option_values, array: true, as: 'OptionValueParams',
                                   description: 'Inline option values. Values left out of the list on update are destroyed, so send the full set every time.' do
              id :id, description: 'Present for existing values. Omit to create a new one.'
              string :name, example: 'red'
              string :label, example: 'Red'
              integer :position
              string :color_code, nullable: true, example: '#FF0000',
                                  description: "Hex color. Only meaningful when the option type's `kind` is `color_swatch`."
              string :image_signed_id, nullable: true, description: 'A `signed_id` from `files.upload()`, or null to remove the image.'
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
