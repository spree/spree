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
          # Returns: { data: [{ type, label, description, preference_schema }] }.
          # The preference_schema array describes the provider-specific
          # configuration fields, so admin UIs can render a generic
          # preferences form without hard-coding per-provider knowledge.
          # Filters out subclasses already installed in the current store —
          # mirrors the legacy admin's "available_payment_methods" helper, so
          # admins don't see (and accidentally double-install) the same
          # provider twice.
          def types
            authorize! :create, model_class

            # Query via direct join rather than `current_store.payment_methods`
            # — the has_many-through association can cache stale results when
            # `current_store` was loaded earlier in the request (e.g. by the
            # auth layer).
            installed_class_names = Spree::PaymentMethod
                                      .joins(:store_payment_methods)
                                      .where(spree_payment_methods_stores: { store_id: current_store.id })
                                      .pluck(:type)
            installed_shorthands = installed_class_names.filter_map do |name|
              name.safe_constantize&.api_type
            end
            available = model_class.subclasses_with_preference_schema.reject do |entry|
              installed_shorthands.include?(entry[:type])
            end

            render json: { data: available }
          end

          protected

          def model_class
            Spree::PaymentMethod
          end

          def serializer_class
            Spree.api.admin_payment_method_serializer
          end

          # Explicit allowlist per the v3 convention — flat params, no
          # reach into the global `Spree::PermittedAttributes` registry
          # (which is the legacy Rails admin's surface). `type` and
          # `preferences` are added by `SubclassedResource` on top.
          def permitted_params
            params.permit(:name, :description, :active, :storefront_visible, :auto_capture, :position, metadata: {}, preferences: {})
          end

          private

          # New payment methods get scoped to the current store automatically.
          def build_subclassed_resource(klass, attrs)
            resource = klass.new(attrs)
            resource.stores = [current_store] if resource.stores.empty?
            resource
          end
        end
      end
    end
  end
end
