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
            shipping_category_ids = params[:shipping_category_ids]

            if resource.class.method_defined?(:shipping_categories) && shipping_category_ids.is_a?(Array)
              resource.shipping_category_ids = shipping_category_ids.compact.uniq
            end
          end

          def model_class
            Spree::ShippingMethod
          end

          def spree_permitted_attributes
            # TODO: Where should we store these? Are we using the core_permitted_attributes.rb still?
            calculator_permitted_attributes = [:preferred_flat_percent, :preferred_amount, :preferred_currency, :preferred_first_item,
                                               :preferred_additional_item, :preferred_max_items, :preferred_percent, :preferred_minimal_amount,
                                               :preferred_normal_amount, :preferred_discount_amount, :preferred_currency, :preferred_base_amount,
                                               :preferred_tiers, :preferred_base_percent]

            additional_permitted_attributes = if action_name == 'update'
                                                [:id]
                                              else
                                                []
                                              end

            Spree::ShippingMethod.json_api_permitted_attributes + [
              { shipping_category_ids: [] },
              {
                calculator_attributes: Spree::Calculator.json_api_permitted_attributes.concat(additional_permitted_attributes,
                                                                                              calculator_permitted_attributes)
              }
            ]
          end
        end
      end
    end
  end
end
