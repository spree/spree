module Spree
  module Api
    module V3
      module Admin
        module PaymentMethods
          # Eligibility rules nested under a payment method. `type` is the
          # wire shorthand from GET /payment_method_rules/types.
          class RulesController < ResourceController
            scoped_resource :settings

            request_params :payment_method_rule do |body|
              body.attribute :type, :string,
                required: true,
                only: :create,
                example: 'channel_rule',
                description: 'A rule kind from the payment method rule types endpoint.'
              body.attribute :active, :boolean, description: 'Defaults to true on create.'
              body.attribute :preferences, :hash, description: "Values for the rule kind's preference schema."
            end

            def create
              rule_class = Spree.payment_method_rules.detect { |klass| klass.api_type == params[:type].to_s }

              if rule_class.nil?
                return render_error(
                  code: ERROR_CODES[:validation_error],
                  message: I18n.t('spree.errors.messages.invalid_payment_method_rule'),
                  status: :unprocessable_content
                )
              end

              @resource = rule_class.new(payment_method: parent, active: active_param)
              assign_rule_attributes(@resource)
              authorize_resource!(@resource, :create)

              if @resource.save
                render json: serialize_resource(@resource), status: :created
              else
                render_validation_error(@resource.errors)
              end
            end

            def update
              @resource.active = active_param unless params[:active].nil?
              assign_rule_attributes(@resource)

              if @resource.save
                render json: serialize_resource(@resource)
              else
                render_validation_error(@resource.errors)
              end
            end

            protected

            def model_class
              Spree::PaymentMethodRule
            end

            def serializer_class
              Spree.api.admin_payment_method_rule_serializer
            end

            def scope
              parent.payment_method_rules
            end

            def permitted_params
              params.permit(*permitted_attributes)
            end

            private

            def parent
              @parent ||= current_store.payment_methods.accessible_by(current_ability, :update).find_by_prefix_id!(params[:payment_method_id])
            end

            def active_param
              params[:active].nil? ? true : params[:active].to_b
            end

            # Fields are assigned by hand rather than mass-assigned, so
            # attributes an extension permitted are forwarded explicitly.
            def assign_rule_attributes(rule)
              rule.assign_preferences(permitted_params[:preferences]) if permitted_params[:preferences]

              keys = model_additional_permitted_attributes.flat_map { |attribute| attribute.is_a?(Hash) ? attribute.keys : attribute }
              rule.assign_attributes(permitted_params.to_h.slice(*keys.map(&:to_s))) if keys.any?
            end
          end
        end
      end
    end
  end
end
