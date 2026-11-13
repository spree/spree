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

      # The verbs a generic write dispatches with. An update is documented as
      # PATCH, or as PUT on the few routes that replace a whole record.
      OPERATION_METHODS = { create: %w[post], update: %w[patch put] }.freeze

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

        # The writable properties of the one operation a tool dispatches to.
        #
        # Read per path and verb rather than per resource: a resource written
        # under a parent (an order's exchanges, a company's addresses) has no
        # top-level body at all, and an update often accepts less than a
        # create — an exchange's items are fixed once it is opened. Checking
        # a write against the wrong list let the endpoint drop an attribute
        # and answer 200.
        #
        # @param path [String] the route template, e.g.
        #   "/api/v3/admin/orders/:order_id/exchanges/:id"
        # @param action [Symbol] :create or :update
        # @return [Hash] JSON Schema properties, empty when the operation
        #   documents no body
        def for_operation(path, action)
          return {} if path.blank?

          operations[[path.to_s, action.to_sym]] ||= begin
            documented = Array(document['paths']).to_h[path.to_s.gsub(/:([a-z_]+)/, '{\\1}')]
            body = Array(OPERATION_METHODS[action.to_sym]).lazy.filter_map do |verb|
              documented&.dig(verb, 'requestBody', 'content', 'application/json', 'schema')
            end.first

            resolve_schema(body)&.dig('properties') || {}
          end
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
          @operations = nil
        end

        private

        def schemas
          @schemas ||= load_schemas
        end

        def operations
          @operations ||= {}
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
