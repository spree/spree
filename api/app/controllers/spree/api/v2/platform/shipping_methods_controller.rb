module Spree
  module Api
    module V2
      module Platform
        class ShippingMethodsController < ResourceController
          def create
            resource = model_class.new(permitted_resource_params)
            assign_shipping_categories(resource, params)
            ensure_current_store(resource)

            if resource.save
              render_serialized_payload(201) { serialize_resource(resource) }
            else
              render_error_payload(resource.errors)
            end
          end

          def update
            assign_shipping_categories(resource, params)
            super
          end

          private

          def assign_shipping_categories(resource, params)
            shipping_category_ids = Spree::ShippingCategory.where(id: params[:shipping_category_ids]).ids

            if resource.class.method_defined?(:shipping_categories) && shipping_category_ids.present?
              resource.shipping_category_ids = shipping_category_ids.compact.uniq
            end
          end

          def model_class
            Spree::ShippingMethod
          end

          def spree_permitted_attributes
            Spree::ShippingMethod.json_api_permitted_attributes + [
              {
                shipping_category_ids: [],
                calculator_attributes: {}
              }
            ]
          end
        end
      end
    end
  end
end
