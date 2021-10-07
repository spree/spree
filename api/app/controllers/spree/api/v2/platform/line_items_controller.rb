module Spree
  module Api
    module V2
      module Platform
        class LineItemsController < ResourceController
          def create
            order = current_store.orders.find(permitted_resource_params[:order_id])

            result = create_service.call(order: order, line_item_attributes: permitted_resource_params)

            if result.success?
              render_serialized_payload(201) { serialize_resource(result.value) }
            else
              render_error_payload(result.error)
            end
          end

          def update
            result = update_service.call(line_item: resource, line_item_attributes: permitted_resource_params)

            if result.success?
              render_serialized_payload { serialize_resource(result.value) }
            else
              render_error_payload(resource.errors)
            end
          end

          def destroy
            result = destroy_service.call(line_item: resource)

            if result.success?
              head 204
            else
              render_error_payload(result.error)
            end
          end

          private

          def model_class
            Spree::LineItem
          end

          def create_service
            Spree::Api::Dependencies.platform_line_item_create_service.constantize
          end

          def update_service
            Spree::Api::Dependencies.platform_line_item_update_service.constantize
          end

          def destroy_service
            Spree::Api::Dependencies.platform_line_item_destroy_service.constantize
          end
        end
      end
    end
  end
end
