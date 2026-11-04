module Spree
  module Api
    module V3
      module Admin
        module PaymentMethods
          # Checkout conditions nested under a payment method. `type` is the
          # wire shorthand from GET /payment_method_rules/types.
          class RulesController < ResourceController
            include Spree::Api::V3::Admin::SubclassedResource

            scoped_resource :settings

            subclassed_via -> { Spree.payment_method_rules },
                           unknown_type_error: 'unknown_payment_method_rule_type'

            request_params :payment_method_rule do |body|
              body.attribute :type, :string,
                required: true,
                only: :create,
                example: 'channel_rule',
                description: 'A rule kind from the payment method rule types endpoint.'
              body.attribute :active, :boolean, description: 'Defaults to true on create.'
              body.attribute :preferences, :hash, description: "Values for the rule kind's preference schema."
            end

            # GET /api/v3/admin/payment_method_rules/types
            def types
              authorize! :read, model_class

              render json: { data: model_class.subclasses_with_preference_schema }
            end

            protected

            def model_class
              Spree::PaymentMethodRule
            end

            def serializer_class
              Spree.api.admin_payment_method_rule_serializer
            end

            def permitted_params
              params.permit(*permitted_attributes)
            end

            def parent_association
              :payment_method_rules
            end

            def read_actions
              super + %w[types]
            end

            def set_parent
              return if action_name == 'types'

              @parent = current_store.payment_methods.accessible_by(current_ability, parent_ability_action).
                        find_by_prefix_id!(params[:payment_method_id])
            end

            private

            def build_subclassed_resource(klass, attrs)
              klass.new(attrs.merge(payment_method: @parent))
            end
          end
        end
      end
    end
  end
end
