module Spree
  module Api
    module V3
      # Declares what a controller's write actions accept (see
      # Spree::Api::V3::RequestSchema). The resource controller permits from the
      # declaration, and the integration specs document it with
      # `request_body_for`, which is where the SDK request types come from.
      #
      #   request_params :product do ... end          # create and update
      #   request_params 'ProductBulkStatusParams', action: :bulk_status_update do ... end
      module RequestParams
        extend ActiveSupport::Concern

        RESOURCE_ACTIONS = %w[create update].freeze

        included do
          class_attribute :request_params_schemas, instance_writer: false, default: {}
        end

        class_methods do
          # @param name [String, Symbol, nil] the resource the published types
          #   are named after (defaults to the singular controller name), or a
          #   name ending in `Params` for a single action's body
          # @param action [Symbol, nil] an action other than create and update
          def request_params(name = nil, action: nil, &block)
            if action && !name.to_s.end_with?('Params')
              raise ArgumentError, "name the body of #{action} with a name ending in Params"
            end

            schema = Spree::Api::V3::RequestSchema.new(name || controller_name.singularize, &block)
            self.request_params_schemas = request_params_schemas.merge((action || :resource).to_sym => schema)
          end

          # @param action [Symbol, String]
          # @return [Spree::Api::V3::RequestSchema, nil] what the action accepts
          def request_params_schema(action = :create)
            action = action.to_s
            request_params_schemas[action.to_sym] || (request_params_schemas[:resource] if RESOURCE_ACTIONS.include?(action))
          end
        end

        protected

        # The current action's declaration. An action without its own (a
        # custom one writing through +permitted_params+) accepts what update
        # does.
        #
        # @return [Spree::Api::V3::RequestSchema, nil]
        def request_params_schema
          self.class.request_params_schema(action_name) || request_params_schemas[:resource]
        end

        # The declared `params.permit` list for the current action.
        #
        # @return [Array<Symbol, Hash>]
        def declared_permitted_attributes
          action = action_name.to_s
          # A member action with no body of its own changes an existing
          # record, so it takes what update takes — never a create-only field.
          request_params_schema.permit_list(RESOURCE_ACTIONS.include?(action) ? action : :update)
        end
      end
    end
  end
end
