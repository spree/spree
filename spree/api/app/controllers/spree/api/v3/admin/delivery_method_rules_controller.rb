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
                preference_schema: klass.serialized_preference_schema,
                # Association-backed config (e.g. `product_ids`) a rule accepts
                # beyond its preferences, so admin UIs can render the right
                # editor without hardcoding rule types.
                association_fields: association_fields_for(klass)
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

          private

          # `additional_permitted_attributes` entries are either bare symbols
          # or `{ product_ids: [] }`-style hashes; both reduce to field names.
          def association_fields_for(klass)
            return [] unless klass.respond_to?(:additional_permitted_attributes)

            klass.additional_permitted_attributes.flat_map do |attribute|
              attribute.is_a?(Hash) ? attribute.keys : attribute
            end.map(&:to_s)
          end
        end
      end
    end
  end
end
