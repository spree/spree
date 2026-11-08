module Spree
  module Api
    # The writable attribute schema for each admin resource, read from the
    # generated OpenAPI document.
    #
    # Not from the controllers: most of them declare their writable attributes
    # inside `permitted_params`, where the list is a `params.permit` call that
    # cannot be read without a request. `admin.yaml` already carries the same
    # list — generated from the integration specs, reviewed as a diff on every
    # API change — with the types, descriptions and examples a model needs to
    # fill a form in correctly. Reading it means the generic write tools offer
    # exactly the documented endpoint and nothing else.
    #
    # Read from {AdminDocument}, so an extension's documented resources
    # count the same as core's.
    module AgentWriteSchemas
      # A collection endpoint under the admin namespace: `/api/v3/admin/markets`
      # but not `/api/v3/admin/markets/{id}` or a nested child.
      COLLECTION_PATH = %r{\A/api/v3/admin/(?<key>[a-z0-9_]+)\z}

      class << self
        # The writable properties for one resource.
        #
        # @param key [String] the resource key, e.g. "markets"
        # @return [Hash] JSON Schema properties, empty when the resource has no
        #   documented write
        def for(key)
          schemas[key.to_s] || {}
        end

        # @return [Array<String>] the attribute names a write may set
        def attribute_names(key)
          self.for(key).keys
        end

        # Core's generated document, which the merged one starts from.
        #
        # @return [Pathname]
        def spec_path
          AdminDocument.core_path
        end

        # The merged document — core's and every extension's — so an
        # extension's resources are generically writable the same way core's
        # are.
        #
        # @return [Hash]
        def document
          AdminDocument.document
        end

        # @return [void]
        def reset!
          @schemas = nil
        end

        private

        def schemas
          @schemas ||= load_schemas
        end

        def load_schemas
          extract(document)
        end

        def extract(document)
          Array(document['paths']).to_h.each_with_object({}) do |(path, operations), result|
            match = COLLECTION_PATH.match(path)
            next if match.nil?

            properties = write_properties(operations)
            result[match[:key]] = properties if properties.present?
          end
        end

        # The create body where there is one, because it documents every
        # settable attribute; an update body usually repeats a subset.
        def write_properties(operations)
          body = operations.dig('post', 'requestBody', 'content', 'application/json', 'schema')
          body ||= operations.dig('patch', 'requestBody', 'content', 'application/json', 'schema')

          resolve_schema(body)&.dig('properties').presence
        end

        public

        # @see AdminDocument.resolve_schema
        def resolve_schema(schema, depth = 0)
          AdminDocument.resolve_schema(schema, depth)
        end
      end
    end
  end
end
