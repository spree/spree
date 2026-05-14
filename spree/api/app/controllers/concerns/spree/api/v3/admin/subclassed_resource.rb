module Spree
  module Api
    module V3
      module Admin
        # Shared `create` / `update` flow for STI parents whose subclass is
        # picked at request time and whose configuration lives in a
        # `preferences` hash (PaymentMethod, PromotionAction, PromotionRule).
        #
        # Including controllers declare:
        #
        #   subclassed_via -> { Spree::PaymentMethod.providers },
        #                  unknown_type_error: 'unknown_payment_method_type'
        #
        # The body picks the subclass against the registry (returns 422 with
        # the configured error code on miss), strips `type`/`preferences`
        # from the permitted attrs, builds/assigns the rest, and routes
        # preference values through the typed `preferred_<name>=` setters
        # so booleans/decimals/etc. get coerced. Unknown preference keys
        # are silently dropped — the schema endpoint is the source of truth
        # for what's settable.
        module SubclassedResource
          extend ActiveSupport::Concern

          class_methods do
            def subclassed_via(registry, unknown_type_error:)
              @subclass_registry = registry
              @unknown_type_error_code = unknown_type_error
            end

            def subclass_registry
              @subclass_registry || (superclass.respond_to?(:subclass_registry) ? superclass.subclass_registry : nil)
            end

            def unknown_type_error_code
              @unknown_type_error_code ||
                (superclass.respond_to?(:unknown_type_error_code) ? superclass.unknown_type_error_code : nil)
            end
          end

          def create
            klass = resolve_subclass(params[:type])
            return render_unknown_type unless klass

            permitted = permitted_params_for(klass)
            attrs, preferences, calculator = extract_subclass_params(permitted)

            @resource = build_subclassed_resource(klass, attrs)
            apply_preferences(@resource, preferences) if preferences.present?
            apply_calculator(@resource, calculator) if calculator.present?
            authorize_resource!(@resource, :create)

            if @resource.save
              render json: serialize_resource(@resource), status: :created
            else
              render_validation_error(@resource.errors)
            end
          end

          def update
            @resource = find_resource
            authorize_resource!(@resource, :update)

            permitted = permitted_params_for(@resource.class)
            attrs, preferences, calculator = extract_subclass_params(permitted)

            @resource.assign_attributes(attrs)
            apply_preferences(@resource, preferences) if preferences.present?
            apply_calculator(@resource, calculator) if calculator.present?

            if @resource.save
              render json: serialize_resource(@resource)
            else
              render_validation_error(@resource.errors)
            end
          end

          private

          # Per-subclass permitted params. Calls `permitted_params` (the base
          # allowlist with `type` + `preferences`) and merges in extras the
          # subclass has declared via `additional_permitted_attributes`.
          # Controllers can override this hook directly if their subclasses
          # expose extras through a different mechanism.
          def permitted_params_for(klass)
            extras = klass.respond_to?(:additional_permitted_attributes) ? klass.additional_permitted_attributes : []
            return permitted_params if extras.blank?

            params.permit(:type, { preferences: {} }, *extras)
          end

          # Default build: top-level resource. Nested controllers (actions,
          # rules) override to attach the parent.
          def build_subclassed_resource(klass, attrs)
            klass.new(attrs)
          end

          def resolve_subclass(type_name)
            return nil if type_name.blank?

            self.class.subclass_registry.call.find { |klass| klass.api_type == type_name.to_s }
          end

          def render_unknown_type
            render_error(
              code: self.class.unknown_type_error_code,
              message: Spree.t("api.#{self.class.unknown_type_error_code}",
                               default: 'Unknown type'),
              status: :unprocessable_content
            )
          end

          def apply_preferences(resource, preferences)
            password_keys = resource.password_preference_keys

            preferences.each do |key, value|
              pref_name = key.to_sym
              next unless resource.has_preference?(pref_name)
              # Round-trip guard: clients fetching a record see masked
              # `:password` values. Submitting the mask back unchanged
              # must NOT overwrite the real secret with `••••cret`.
              next if password_keys.include?(pref_name) && Spree::Preferences::Masking.masked?(value)

              resource.set_preference(pref_name, value)
            end
          end

          # Pulls `preferences` and `calculator` out of the permitted
          # params so they can be routed through their typed setters
          # (`set_preference`, `assign_calculator_attributes`) instead
          # of generic `assign_attributes`. The remaining hash is
          # safe to pass through as plain attribute assignments.
          def extract_subclass_params(permitted)
            permitted = permitted.respond_to?(:to_unsafe_h) ? permitted.to_unsafe_h.with_indifferent_access : permitted.with_indifferent_access
            permitted.delete(:type) # subclass is already resolved; don't let it overwrite STI column
            preferences = permitted.delete(:preferences)
            calculator = permitted.delete(:calculator)
            [permitted, preferences, calculator]
          end

          def apply_calculator(resource, calculator)
            return unless resource.respond_to?(:assign_calculator_attributes)

            resource.assign_calculator_attributes(calculator)
          end
        end
      end
    end
  end
end
