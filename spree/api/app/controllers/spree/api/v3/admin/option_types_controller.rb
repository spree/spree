module Spree
  module Api
    module V3
      module Admin
        class OptionTypesController < ResourceController
          scoped_resource :products

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
            params.permit(
              :name, :label, :position, :filterable, :kind,
              option_values: [
                :id, :name, :label, :position, :color_code, :image
              ]
            )
          end
        end
      end
    end
  end
end
