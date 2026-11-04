module Spree
  module Api
    module V3
      module Admin
        class PaymentMethodRulesController < ResourceController
          scoped_resource :settings

          # GET /api/v3/admin/payment_method_rules/types
          # Registered rule kinds with preference schemas for admin pickers.
          def types
            authorize! :create, Spree::PaymentMethodRule

            data = Spree.payment_method_rules.map do |klass|
              {
                type: klass.api_type,
                name: klass.human_name,
                description: klass.human_description,
                schema: klass.preference_json_schema
              }
            end

            render json: { data: data }
          end

          protected

          def model_class
            Spree::PaymentMethodRule
          end

          def serializer_class
            Spree.api.admin_payment_method_rule_serializer
          end
        end
      end
    end
  end
end
