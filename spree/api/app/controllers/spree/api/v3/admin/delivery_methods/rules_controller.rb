module Spree
  module Api
    module V3
      module Admin
        module DeliveryMethods
          # Eligibility rules nested under a delivery method. `type` is the
          # wire shorthand from GET /delivery_method_rules/types.
          class RulesController < ResourceController
            scoped_resource :settings

            def create
              rule_class = Spree.delivery_method_rules.detect do |klass|
                klass.api_type == params[:type].to_s || klass.to_s == params[:type].to_s
              end

              if rule_class.nil?
                return render_error(
                  code: ERROR_CODES[:validation_error],
                  message: Spree.t('errors.messages.invalid_delivery_method_rule'),
                  status: :unprocessable_entity
                )
              end

              @resource = rule_class.new(delivery_method: parent, active: active_param)
              assign_rule_preferences(@resource)
              authorize_resource!(@resource, :create)

              if @resource.save
                render json: serialize_resource(@resource), status: :created
              else
                render_validation_error(@resource.errors)
              end
            end

            def update
              @resource.active = active_param unless params[:active].nil?
              assign_rule_preferences(@resource)

              if @resource.save
                render json: serialize_resource(@resource)
              else
                render_validation_error(@resource.errors)
              end
            end

            protected

            def model_class
              Spree::DeliveryMethodRule
            end

            def serializer_class
              Spree.api.admin_delivery_method_rule_serializer
            end

            def scope
              parent.delivery_method_rules
            end

            def permitted_params
              params.permit(:type, :active, preferences: {})
            end

            private

            def parent
              @parent ||= Spree::DeliveryMethod.accessible_by(current_ability, :update).find_by_prefix_id!(params[:delivery_method_id])
            end

            def active_param
              params[:active].nil? ? true : ActiveModel::Type::Boolean.new.cast(params[:active])
            end

            def assign_rule_preferences(rule)
              (permitted_params[:preferences] || {}).each do |key, value|
                next unless rule.has_preference?(key)

                rule.set_preference(key, value)
              end
            end
          end
        end
      end
    end
  end
end
