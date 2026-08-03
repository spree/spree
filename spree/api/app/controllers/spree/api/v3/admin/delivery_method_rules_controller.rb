module Spree
  module Api
    module V3
      module Admin
        class DeliveryMethodRulesController < ResourceController
          scoped_resource :settings

          # GET /api/v3/admin/delivery_method_rules/types
          # Registered rule kinds with preference schemas for admin pickers.
          def types
            authorize! :create, Spree::DeliveryMethodRule

            data = Spree.delivery_method_rules.map do |klass|
              {
                type: klass.api_type,
                name: klass.human_name,
                description: klass.human_description,
                preference_schema: klass.serialized_preference_schema
              }
            end

            render json: { data: data }
          end

          protected

          def model_class
            Spree::DeliveryMethodRule
          end

          def serializer_class
            Spree.api.admin_delivery_method_rule_serializer
          end
        end
      end
    end
  end
end
