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
              assign_rule_products(@resource)
              assign_extension_attributes(@resource)
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
              assign_rule_products(@resource)
              assign_extension_attributes(@resource)

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
              params.permit(*model_additional_permitted_attributes, :type, :active, preferences: {}, product_ids: [])
            end

            private

            def parent
              @parent ||= current_store.delivery_methods.accessible_by(current_ability, :update).find_by_prefix_id!(params[:delivery_method_id])
            end

            def active_param
              params[:active].nil? ? true : params[:active].to_b
            end

            # This controller assigns each field by hand rather than mass-assigning,
            # so attributes an extension contributed have to be forwarded too or
            # permitting them would have no effect.
            def assign_extension_attributes(rule)
              keys = model_additional_permitted_attributes.flat_map { |a| a.is_a?(Hash) ? a.keys : a }
              return if keys.empty?

              rule.assign_attributes(permitted_params.to_h.slice(*keys.map(&:to_s)))
            end

            def assign_rule_preferences(rule)
              (permitted_params[:preferences] || {}).each do |key, value|
                next unless rule.has_preference?(key)

                rule.set_preference(key, value)
              end
            end

            # Association-backed rule config (ExcludedProductsRule). Products are
            # looked up within the rule's store and through the caller's ability;
            # ids that resolve to nothing are dropped rather than failing the
            # save, since an unreachable product cannot become an exclusion. A
            # nil param leaves the selection untouched; an empty array clears it.
            def assign_rule_products(rule)
              ids = permitted_params[:product_ids]
              return if ids.nil? || !rule.respond_to?(:products)

              rule.products = rule.store.products.
                              accessible_by(current_ability, :show).
                              where(id: decode_prefixed_ids(ids))
            end
          end
        end
      end
    end
  end
end
