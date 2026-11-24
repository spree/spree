require 'spree/api/openapi/schema_helper'
require 'spree/api/sdk_types'

module Spree
  module Api
    module TestingSupport
      # Documents a successful response with the schema of the serializer its
      # controller renders, so an integration spec declares a schema only for
      # an endpoint that answers with something else:
      #
      #   response '200', 'order found' do
      #     run_test!   # documented as `Order`, and the response is checked against it
      #   end
      #
      # `index` answers with the paginated list of that schema and every other
      # action with the resource itself. A response block that calls `schema`
      # keeps what it declared.
      module ResponseSchema
        class << self
          # @param controller [ActionController::Metal] the controller that answered
          # @param document [Hash] the OpenAPI document the operation is written to
          # @return [Hash, nil] nil when the controller renders no serializer the document publishes
          def for(controller, document)
            schemas = document.dig(:components, :schemas)
            name = schema_name(controller) if schemas.present?
            return unless name && (schemas.key?(name) || schemas.key?(name.to_sym))

            controller.action_name == 'index' ? OpenAPI::SchemaHelper.paginated(name) : OpenAPI::SchemaHelper.ref(name)
          end

          private

          def schema_name(controller)
            return unless controller.respond_to?(:serializer_class, true)

            serializer = controller.send(:serializer_class)
            schema_names(SdkTypes.api_of(serializer))[serializer]
          rescue NotImplementedError
            nil
          end

          def schema_names(api)
            @schema_names ||= {}
            @schema_names[api] ||= Typelizer.interfaces(writer_name: api).to_h { |interface| [interface.serializer, interface.name] }
          end
        end

        def run_test!(...)
          super

          # After rswag's own `before`, which sends the request, and ahead of
          # the example, which validates the response against the schema.
          before do |example|
            next unless response.successful? && response.media_type == 'application/json' && response.body.present?

            specs = RSpec.configuration.openapi_specs
            document = specs.fetch(example.metadata[:openapi_spec] || example.metadata[:swagger_doc] || specs.keys.first)
            example.metadata[:response][:schema] ||= ResponseSchema.for(controller, document)
          end
        end
      end
    end
  end
end
