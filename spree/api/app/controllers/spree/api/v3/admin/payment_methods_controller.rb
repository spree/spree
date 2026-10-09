module Spree
  module Api
    module V3
      module Admin
        class PaymentMethodsController < ResourceController
          include Spree::Api::V3::Admin::SubclassedResource

          scoped_resource :settings

          subclassed_via -> { Spree::PaymentMethod.providers },
                         unknown_type_error: 'unknown_payment_method_type'

          # Lists available payment provider subclasses for the create form.
          # Returns: { data: [{ type, label, description, schema }] }.
          # `schema` is the JSON Schema of the provider-specific
          # configuration fields, so admin UIs can render a generic
          # preferences form without hard-coding per-provider knowledge.
          # Every provider, `installed` when the store already has one: the
          # create picker leaves those out so a provider is not installed
          # twice, and the edit form still finds an installed one's schema.
          def types
            authorize! :create, model_class

            installed_class_names = current_store.payment_methods.pluck(:type)
            installed_shorthands = installed_class_names.filter_map do |name|
              name.safe_constantize&.api_type
            end
            entries = model_class.subclasses_with_preference_schema.map do |entry|
              entry.merge(installed: installed_shorthands.include?(entry[:type]))
            end

            render json: { data: entries }
          end

          protected

          def model_class
            Spree::PaymentMethod
          end

          def serializer_class
            Spree.api.admin_payment_method_serializer
          end

          # Explicit allowlist per the v3 convention — flat params. `type` and
          # `preferences` are added by `SubclassedResource` on top.
          # Deliberately NOT routed through `normalize_params`: `metadata` holds
          # opaque merchant values, and prefixed-ID resolution recurses into
          # nested hashes — a value like `we_1MqJ8b...` matches the prefixed-ID
          # shape and would be decoded to an integer. `preferences` decode their
          # own ids from their schema.
          def permitted_params
            params.permit(
              :name, :description, :active, :storefront_visible, :auto_capture, :capture_method, :position,
              *model_additional_permitted_attributes,
              metadata: {}, preferences: {}
            )
          end

          def scope
            super.ordered
          end

          # `types` is read-only discovery — maps to the read scope + :show ability.
          def read_actions
            super + %w[types]
          end

          private

          # New payment methods are created through the current store.
          def build_subclassed_resource(klass, attrs)
            current_store.payment_methods.build(attrs.merge(type: klass.sti_name))
          end
        end
      end
    end
  end
end
