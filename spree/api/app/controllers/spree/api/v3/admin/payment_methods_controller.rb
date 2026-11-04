module Spree
  module Api
    module V3
      module Admin
        class PaymentMethodsController < ResourceController
          include Spree::Api::V3::Admin::SubclassedResource

          scoped_resource :settings

          subclassed_via -> { Spree::PaymentMethod.providers },
                         unknown_type_error: 'unknown_payment_method_type'

          request_params :payment_method do |body|
            body.attribute :type, :string,
              required: true,
              only: :create,
              permit: false,
              example: 'check',
              description: 'Wire shorthand from the payment method types endpoint.'
            body.attribute :name, :string, required: true, on: :create
            body.attribute :description, :string, nullable: true
            body.attribute :active, :boolean
            body.attribute :storefront_visible, :boolean,
              description: 'False keeps the method to the dashboard; true also offers it on the storefront.'
            body.attribute :capture_method, :string,
              nullable: true,
              choices: Spree::CaptureMethod::CAPTURE_METHODS,
              description: 'When customers are charged for this method. Null inherits the store setting.'
            body.attribute :position, :integer
            body.attribute :metadata, :hash
            body.attribute :preferences, :hash,
              description: "Values for the provider's preference schema, from the payment method types endpoint."
            body.attribute :rules, :array,
              permit: false,
              description: 'Conditions that decide whether the method is offered at storefront checkout. Replaces the full set: omitted rules are removed.' do |rule|
              rule.attribute :id, :id
              rule.attribute :type, :string, description: 'A rule kind from the payment method rule types endpoint.'
              rule.attribute :active, :boolean
              rule.attribute :preferences, :hash
            end
          end

          # Lists available payment provider subclasses for the create form.
          # Returns: { data: [{ type, label, description, schema }] }.
          # `schema` is the JSON Schema of the provider-specific
          # configuration fields, so admin UIs can render a generic
          # preferences form without hard-coding per-provider knowledge.
          # Every provider with `installed_count`, how many methods of it the
          # store has. A store may hold several of one provider — one per
          # account, each scoped by rules — so the count never gates adding
          # another. `installed` is deprecated (removed in 6.2).
          def types
            authorize! :show, model_class

            counts = current_store.payment_methods.group(:type).count.each_with_object(Hash.new(0)) do |(name, count), by_type|
              api_type = name.safe_constantize&.api_type
              by_type[api_type] += count if api_type
            end
            entries = model_class.subclasses_with_preference_schema.map do |entry|
              entry.merge(installed_count: counts[entry[:type]], installed: counts[entry[:type]].positive?)
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

          # `type` is read by `SubclassedResource` from the raw params.
          # Deliberately NOT routed through `normalize_params`: `metadata` holds
          # opaque merchant values, and prefixed-ID resolution recurses into
          # nested hashes — a value like `we_1MqJ8b...` matches the prefixed-ID
          # shape and would be decoded to an integer. `preferences` decode their
          # own ids from their schema.
          def permitted_params
            params.permit(*permitted_attributes, rules: [:id, :type, :active, { preferences: {} }])
          end

          def scope
            super.ordered
          end

          def collection_includes
            [:payment_method_rules]
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
