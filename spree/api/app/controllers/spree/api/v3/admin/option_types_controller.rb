module Spree
  module Api
    module V3
      module Admin
        class OptionTypesController < ResourceController
          # POST /api/v3/admin/option_types
          def create
            authorize!(:create, Spree::OptionType)

            result = Spree.option_type_create_service.call(
              params: option_type_service_params
            )

            if result.success?
              @resource = result.value[:option_type]
              render json: serialize_resource(@resource), status: :created
            else
              render_result_error(result)
            end
          end

          # PATCH /api/v3/admin/option_types/:id
          def update
            result = Spree.option_type_update_service.call(
              option_type: @resource,
              params: option_type_service_params
            )

            if result.success?
              @resource = result.value[:option_type]
              render json: serialize_resource(@resource)
            else
              render_result_error(result)
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

          private

          def render_result_error(result)
            error = result.error
            errors = error.respond_to?(:value) ? error.value : error

            if errors.is_a?(ActiveModel::Errors)
              render_validation_error(errors)
            else
              render_service_error(error)
            end
          end

          def option_type_service_params
            params.permit(
              :name, :presentation, :position, :filterable,
              option_values: [:id, :name, :presentation, :position]
            )
          end
        end
      end
    end
  end
end
