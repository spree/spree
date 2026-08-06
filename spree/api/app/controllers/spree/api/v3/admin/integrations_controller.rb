module Spree
  module Api
    module V3
      module Admin
        # Credential records for provider gems (delivery rates, tax, ...) —
        # one per (store, type). The types endpoint is the dashboard's
        # gallery source; activation is verified by the model
        # (verify-before-activate), so a failed connection surfaces as a
        # plain 422 on `active`.
        class IntegrationsController < ResourceController
          include Spree::Api::V3::Admin::SubclassedResource

          scoped_resource :integrations

          subclassed_via -> { Spree::Integration.registered_classes },
                         unknown_type_error: 'unknown_integration_type'

          # GET /api/v3/admin/integrations/types
          # Pure registry discovery — which integrations are installed and how
          # they're configured. Deliberately carries no per-store connected
          # state: clients cache this long-lived and read live connection
          # state from the integrations list instead.
          def types
            authorize! :create, model_class

            render json: { data: Spree::Integration.discovery_entries }
          end

          # POST /api/v3/admin/integrations/:id/test
          # Live connection check; nothing is persisted.
          def test
            @resource = find_resource
            authorize_resource!(@resource, :update)

            connected = @resource.can_connect?
            render json: { connected: connected, error_message: connected ? nil : @resource.connection_error_message }
          end

          protected

          def model_class
            Spree::Integration
          end

          def serializer_class
            Spree.api.admin_integration_serializer
          end

          def permitted_params
            params.permit(:type, :active, preferences: {})
          end

          # `types` is read-only discovery — maps to the read scope.
          def read_actions
            super + %w[types]
          end

          private

          def build_subclassed_resource(klass, attrs)
            current_store.integrations.build(attrs.merge(type: klass.sti_name))
          end
        end
      end
    end
  end
end
