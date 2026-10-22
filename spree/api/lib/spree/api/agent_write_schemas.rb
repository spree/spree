module Spree
  module Api
    # The writable attribute schema for each admin resource, read from the
    # controllers' own request declarations.
    #
    # A controller declares what its write actions accept with
    # `request_params` (see Spree::Api::V3::RequestSchema), and the API
    # reference and the SDK request types are generated from that same
    # declaration. Reading it here means the generic write tools offer exactly
    # the endpoint's body — and offer it wherever the gem is installed. The
    # generated document these used to be read from is not shipped with the
    # gem, so a packaged installation had no write bodies at all: workflow
    # tools sent empty bodies, and the attribute filter had nothing to check a
    # tenancy key against.
    #
    # Built once, lazily, and forgotten on reload with the resource map:
    # deriving it loads every admin controller, which a developer who never
    # runs an agent should not pay for on each file save.
    module AgentWriteSchemas
      # A top-level collection: `/api/v3/admin/markets`, but not a nested
      # child such as `/api/v3/admin/orders/:order_id/fulfillments`. The
      # generic tools address a record by its id alone and have no parent id
      # to fill in, so a nested resource is written through its workflow tool
      # instead.
      COLLECTION_PATH = %r{\A/api/v3/admin/[a-z0-9_]+\z}

      class << self
        # The writable properties for one resource.
        #
        # @param key [String] the resource key, e.g. "markets"
        # @return [Hash] JSON Schema properties, empty when the resource
        #   declares no write body
        def for(key)
          schemas[key.to_s] || {}
        end

        # @return [Array<String>] the attribute names a write may set
        def attribute_names(key)
          self.for(key).keys
        end

        # What one action of a controller accepts, as plain properties.
        #
        # @param controller [Class]
        # @param action [Symbol, String]
        # @return [Hash] JSON Schema properties keyed by attribute name, empty
        #   when the action declares no body
        def body_properties(controller, action)
          return {} unless controller.respond_to?(:request_params_schema)

          schema = controller.request_params_schema(action)
          return {} if schema.nil?

          resolve_schema(plain(schema.json_schema(action.to_sym)))&.dig('properties') || {}
        end

        # A body is declared once and published as a component, so an
        # operation may carry a `$ref` to it rather than the properties
        # themselves. A body that builds on a shared shape is an `allOf` of
        # that shape and its own fields, read as one object. Followed a few
        # hops, which is as deep as the declarations nest.
        #
        # @param schema [Hash, nil] a schema that may be a reference
        # @return [Hash, nil] the schema it names
        def resolve_schema(schema, depth = 0)
          return unless schema.is_a?(Hash)
          return if depth > 3
          return merge_all_of(schema['allOf'], depth) if schema.key?('allOf')
          return schema unless schema.key?('$ref')

          name = schema['$ref'].to_s.split('/').last
          resolve_schema(components[name], depth + 1)
        end

        # Forgets what was derived, so the next reader rebuilds it from the
        # reloaded controllers.
        #
        # @return [void]
        def reset!
          @schemas = nil
          @components = nil
        end

        private

        def schemas
          @schemas ||= load_schemas
        end

        # One controller per resource: the one whose create operation sits at
        # the top-level collection path. A resource without one is read-only
        # here, because a write tool with no attributes is one an agent can
        # only get wrong.
        def load_schemas
          AgentResourceMap.controllers.each_with_object({}) do |controller, result|
            next unless AgentResourceMap.api_paths_for(controller)[:create]&.match?(COLLECTION_PATH)

            key = AgentResourceMap.key_for_controller(controller)
            next if key.nil? || result.key?(key)

            properties = body_properties(controller, :create)
            result[key] = properties if properties.present?
          end
        end

        # Every named shape an admin controller publishes, and the code lists
        # (`CountryCode`, `CurrencyCode`), under the component names the
        # declarations refer to them by.
        def components
          @components ||= AgentResourceMap.controllers.each_with_object({}) do |controller, all|
            next unless controller.respond_to?(:request_params_schemas)

            controller.request_params_schemas.each_value do |schema|
              schema.shapes.each { |shape| all[shape.name] ||= plain(shape.json_schema) }
              plain(schema.code_lists).each { |name, list| all[name] ||= list }
            end
          end
        end

        def merge_all_of(parts, depth)
          parts.filter_map { |part| resolve_schema(part, depth + 1) }.each_with_object({}) do |part, merged|
            merged['properties'] = (merged['properties'] || {}).merge(part['properties'] || {})
            merged['required'] = (merged['required'] || []) | Array(part['required'])
          end
        end

        # The declaration's JSON as a client would read it: string keys, and
        # the type words as strings rather than the symbols the DSL uses.
        def plain(value)
          JSON.parse(JSON.generate(value))
        end
      end
    end
  end
end
