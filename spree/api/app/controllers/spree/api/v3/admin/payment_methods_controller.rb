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
          end

          # Lists available payment provider subclasses for the create form.
          # Returns: { data: [{ type, label, description, schema }] }.
          # `schema` is the JSON Schema of the provider-specific
          # configuration fields, so admin UIs can render a generic
          # preferences form without hard-coding per-provider knowledge.
          # Every provider, `installed` when the store already has one: the
          # create picker leaves those out so a provider is not installed
          # twice, and the edit form still finds an installed one's schema.
          def types
            authorize! :show, model_class

            installed_class_names = current_store.payment_methods.pluck(:type)
            installed_shorthands = installed_class_names.filter_map do |name|
              name.safe_constantize&.api_type
            end
            entries = model_class.subclasses_with_preference_schema.map do |entry|
              entry.merge(installed: installed_shorthands.include?(entry[:type]))
            end

            render json: { data: serialize_types(entries, Spree.api.admin_payment_method_type_serializer) }
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
            params.permit(*permitted_attributes)
          end

          # The add-payment dialog on an order picks from this list, so staff
          # who manage payments read it without the settings key. Writing, and
          # the provider types, stay a settings matter.
          def scoped_resource_name
            reads_through_payments? ? :payments : super
          end

          def scope
            reads_through_payments? ? current_store.payment_methods.ordered : super.ordered
          end

          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            return authorize!(:show, Spree::Payment) if reads_through_payments?

            super
          end

          def reads_through_payments?
            return @reads_through_payments if defined?(@reads_through_payments)

            @reads_through_payments = %w[index show].include?(action_name) &&
                                      !holds_permission?('read_settings') &&
                                      holds_permission?('read_payments')
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
